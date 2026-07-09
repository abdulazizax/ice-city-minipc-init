#include <avr/wdt.h>
#include <string.h>

// Pin definitions
int switchPin = 2;
int relayPin = 8;
int resetPin = 12;

// State tracking
bool gateIsOpen = false;
bool passSentThisOpen = false; // only one PASS per gate-open cycle (sensor bounce / multi-trigger)
bool lastSwitchState = HIGH;
unsigned long lastTriggerTime = 0;
unsigned long debounceDelay = 500; // ms — sensors close together can bounce; 200ms was too short
unsigned long lastHeartbeat = 0;

// Auto-close: if nobody passes within this time, Arduino closes the gate itself
unsigned long gateOpenTime = 0;
const unsigned long AUTO_CLOSE_MS = 5000;

// Cooldown after gate close: reject OPEN commands for this duration.
// Prevents duplicate OPEN from one scan burst; keep low so the next person is not blocked in high traffic.
unsigned long gateCloseTime = 0;
const unsigned long CLOSE_COOLDOWN_MS = 800;

void setup() {
  wdt_enable(WDTO_8S);

  pinMode(switchPin, INPUT_PULLUP);
  pinMode(relayPin, OUTPUT);
  pinMode(resetPin, OUTPUT);
  digitalWrite(resetPin, HIGH);

  digitalWrite(relayPin, LOW);
  gateIsOpen = false;

  // ✅ Initialize serial and wait for USB connection
  Serial.begin(9600);
  while (!Serial && millis() < 5000) {
    // Wait up to 5 seconds for USB serial to connect
    delay(100);
  }
  Serial.setTimeout(100);

  delay(200); // Extra stabilization

  // ✅ Send READY signal immediately (needed for Go handshake)
  Serial.println("READY");
  // Serial.println("GATE-V8-ONEPASS");
  // Serial.println("Commands: OPEN, CLOSE, STATUS, REBOOT");
  // Serial.println("");

  lastSwitchState = digitalRead(switchPin);
  lastHeartbeat = millis();

  // printStatus(); // debug: initial status spam
}

void loop() {
  wdt_reset();

  // ✅ Detect USB disconnect and reconnect
  if (!Serial) {
    // USB disconnected - wait for reconnection
    while (!Serial) {
      delay(100);
    }
    // USB reconnected - re-announce
    delay(200); // Let USB stabilize
    Serial.println("READY");
    // Serial.println("🔌 USB Reconnected");
    // printStatus();
  }

  // ✅ Announce presence every 2 seconds (disabled — floods serial logs)
  // static unsigned long lastAnnounce = 0;
  // if (millis() - lastAnnounce > 2000) {
  //   Serial.println("READY");
  //   lastAnnounce = millis();
  // }

  // Switch detection
  bool currentSwitchState = digitalRead(switchPin);
  if (lastSwitchState == HIGH && currentSwitchState == LOW) {
    if (millis() - lastTriggerTime > debounceDelay) {
      if (gateIsOpen && !passSentThisOpen) {
        // PASS must be sent BEFORE closeGate() so the host receives "PASS" before "Gate CLOSED".
        // Otherwise Go clears lastOpenedAccess on CLOSED and /pass is never sent.
        passSentThisOpen = true;
        Serial.println("PASS");
        closeGate();
      } else {
        // Serial.println("SWITCH:ignored");
      }
      lastTriggerTime = millis();
    }
  }
  lastSwitchState = currentSwitchState;

  // Serial command processing
  static char cmdBuffer[32];
  static int cmdIndex = 0;

  while (Serial.available()) {
    int inByte = Serial.read();
    if (inByte < 0)
      continue;

    // lastAnnounce = millis(); // announce loop disabled

    if (inByte == '\n' || inByte == '\r') {
      if (cmdIndex > 0) {
        cmdBuffer[cmdIndex] = '\0';
        processCommand(cmdBuffer);
        cmdIndex = 0;
      }
    } else if (cmdIndex < (sizeof(cmdBuffer) - 1)) {
      cmdBuffer[cmdIndex++] = (char)inByte;
    } else {
      cmdIndex = 0;
    }
  }

  // Auto-close: if gate is open and nobody passed within AUTO_CLOSE_MS, close it.
  // TIMEOUT must be sent BEFORE closeGate() so the host receives "TIMEOUT" before "Gate CLOSED".
  // This lets Go distinguish timeout-close from pass-close (where PASS event may be lost).
  if (gateIsOpen && gateOpenTime > 0 && (millis() - gateOpenTime) >= AUTO_CLOSE_MS) {
    Serial.println("TIMEOUT");
    closeGate();
  }

  // Heartbeat (disabled — floods serial logs)
  // if (millis() - lastHeartbeat > 5000) {
  //   Serial.print("💓 OK:");
  //   Serial.print(millis());
  //   Serial.print(":");
  //   Serial.println(gateIsOpen ? "OPEN" : "CLOSED");
  //   lastHeartbeat = millis();
  // }

  delay(10);
}

// --- COMMAND PROCESSING ---
void processCommand(char *cmd) {
  // Remove trailing whitespace
  int len = strlen(cmd);
  while (len > 0 && (cmd[len - 1] == ' ' || cmd[len - 1] == '\t')) {
    cmd[--len] = '\0';
  }

  // Convert to uppercase manually
  for (int i = 0; cmd[i]; i++) {
    cmd[i] = toupper(cmd[i]);
  }

  // Process command
  if (strcmp(cmd, "OPEN") == 0) {
    openGate();
    // Serial.println("📱 OPEN command received");
  } else if (strcmp(cmd, "CLOSE") == 0) {
    closeGate();
    // Serial.println("📱 CLOSE command received");
  } else if (strcmp(cmd, "STATUS") == 0) {
    printStatus(); // silent when printStatus body is commented out
  } else if (strcmp(cmd, "REBOOT") == 0) {
    // Serial.println("♻️ REBOOT command received - resetting now!");
    delay(100);
    hardwareReset();
  } else if (strlen(cmd) > 0) {
    Serial.print("❌ Unknown: ");
    Serial.println(cmd);
  }
}

// --- GATE CONTROL ---
void openGate() {
  // Already open: ignore duplicate OPEN (prevents timer reset from rapid scans)
  if (gateIsOpen) {
    Serial.println("⏳ OPEN ignored (already open)");
    return;
  }
  if (gateCloseTime > 0 && (millis() - gateCloseTime) < CLOSE_COOLDOWN_MS) {
    Serial.println("⏳ OPEN ignored (cooldown active)");
    return;
  }
  digitalWrite(relayPin, HIGH);
  gateIsOpen = true;
  passSentThisOpen = false;
  gateCloseTime = 0;
  gateOpenTime = millis();
  if (gateOpenTime == 0) gateOpenTime = 1;
  Serial.println("🔓 Gate OPENED");
}

void closeGate() {
  digitalWrite(relayPin, LOW);
  gateIsOpen = false;
  gateCloseTime = millis();
  if (gateCloseTime == 0) gateCloseTime = 1;
  Serial.println("🔒 Gate CLOSED");
}

// --- STATUS REPORTING ---
void printStatus() {
  // Minimal STATUS response — needed for Go heartbeat health-check.
  // Go sends STATUS every 5s; without a response it assumes dead link and reconnects.
  Serial.println("=== STATUS ===");
  Serial.print("Gate: ");
  Serial.println(gateIsOpen ? "OPEN" : "CLOSED");
  Serial.println("================");
  // Verbose debug lines kept commented:
  // Serial.print("Switch (Pin 2): ");
  // Serial.println(switchState ? "HIGH (no motion)" : "LOW (motion)");
  // Serial.print("Uptime: "); Serial.print(millis() / 1000); Serial.println("s");
  // Serial.print("Free RAM: "); Serial.print(freeRam()); Serial.println(" bytes");
}

// --- DEBUG UTILITIES ---
int freeRam() {
  extern int __heap_start, *__brkval;
  int v;
  return (int)&v - (__brkval == 0 ? (int)&__heap_start : (int)__brkval);
}

// --- HARDWARE SELF-RESET ---
void hardwareReset() {
  digitalWrite(resetPin, LOW);
  delay(1000);
}
