#include <avr/wdt.h>
#include <string.h>

// Serial protocol (9600 baud, unchanged so old and new firmware work with the
// same Go backend):
//   from host: OPEN, CLOSE, STATUS, REBOOT
//   to host:   "Gate OPENED", "Gate CLOSED", "PASS", "TIMEOUT",
//              "OPEN ignored (...)", "=== STATUS ===" block, "READY"
// "PASS" / "TIMEOUT" are always sent before the "Gate CLOSED" they cause.

// Pin definitions. switchPin must be an interrupt pin (2 or 3 on Uno/Nano).
const int switchPin = 2;
const int relayPin = 8;
const int resetPin = 12;

// Ignore sensor edges closer than this (contact bounce of one rotation).
const unsigned long DEBOUNCE_MS = 200;
// Ignore a sensor edge this soon after opening: nobody passes this fast, so it
// is noise or the arm settling.
const unsigned long MIN_OPEN_MS = 100;
// Auto-close: if nobody passes within this time, the Arduino closes the gate.
const unsigned long AUTO_CLOSE_MS = 3000;
// Cooldown after a close: reject OPEN for this long. Prevents a duplicate OPEN
// from one scan burst; low so the next person is not blocked.
const unsigned long CLOSE_COOLDOWN_MS = 800;

// State shared with the interrupt handler.
volatile bool gateIsOpen = false;
volatile bool passPending = false;
volatile unsigned long gateOpenTime = 0;
volatile unsigned long gateCloseTime = 0;
volatile unsigned long lastTriggerTime = 0;

unsigned long lastHeartbeat = 0;
unsigned long lastAnnounce = 0;

// onSwitchFalling runs the moment the rotation sensor fires, even while the
// loop is busy writing to serial. It locks the gate right away; the loop then
// reports PASS. Polling missed short pulses during long serial writes, which
// left the gate unlocked until the auto-close and let it turn several times.
void onSwitchFalling() {
  unsigned long now = millis();
  if (now - lastTriggerTime < DEBOUNCE_MS) return;
  lastTriggerTime = now;

  if (!gateIsOpen) return;
  if (now - gateOpenTime < MIN_OPEN_MS) return;

  digitalWrite(relayPin, LOW);
  gateIsOpen = false;
  gateCloseTime = now;
  if (gateCloseTime == 0) gateCloseTime = 1;
  passPending = true;
}

void setup() {
  wdt_enable(WDTO_8S);

  pinMode(switchPin, INPUT_PULLUP);
  pinMode(relayPin, OUTPUT);
  pinMode(resetPin, OUTPUT);
  digitalWrite(resetPin, HIGH);

  digitalWrite(relayPin, LOW);
  gateIsOpen = false;

  Serial.begin(9600);
  while (!Serial && millis() < 5000) {
    delay(100);
  }
  Serial.setTimeout(100);
  delay(200);

  Serial.println("READY");
  Serial.println("GATE-V8-INTERRUPT");
  Serial.println("Commands: OPEN, CLOSE, STATUS, REBOOT");

  attachInterrupt(digitalPinToInterrupt(switchPin), onSwitchFalling, FALLING);

  lastHeartbeat = millis();
  lastAnnounce = millis();
  printStatus();
}

void loop() {
  wdt_reset();

  if (!Serial) {
    while (!Serial) {
      wdt_reset();
      delay(100);
    }
    delay(200);
    Serial.println("READY");
    Serial.println("USB Reconnected");
    printStatus();
  }

  // A pass caught by the interrupt: the gate is already locked.
  bool passed;
  noInterrupts();
  passed = passPending;
  passPending = false;
  interrupts();
  if (passed) {
    Serial.println("PASS");
    Serial.println("Gate CLOSED");
  }

  // Auto-close when nobody passed in time.
  bool timedOut = false;
  noInterrupts();
  if (gateIsOpen && gateOpenTime > 0 && (millis() - gateOpenTime) >= AUTO_CLOSE_MS) {
    lockGate();
    timedOut = true;
  }
  interrupts();
  if (timedOut) {
    Serial.println("TIMEOUT");
    Serial.println("Gate CLOSED");
  }

  readCommands();

  // Presence announce (keeps the host's idle watchdog fed).
  if (millis() - lastAnnounce > 2000) {
    Serial.println("READY");
    lastAnnounce = millis();
  }

  if (millis() - lastHeartbeat > 5000) {
    Serial.print("OK:");
    Serial.print(millis());
    Serial.print(":");
    Serial.println(gateIsOpen ? "OPEN" : "CLOSED");
    lastHeartbeat = millis();
  }

  delay(1);
}

void readCommands() {
  static char cmdBuffer[32];
  static int cmdIndex = 0;

  while (Serial.available()) {
    int inByte = Serial.read();
    if (inByte < 0) continue;

    lastAnnounce = millis();

    if (inByte == '\n' || inByte == '\r') {
      if (cmdIndex > 0) {
        cmdBuffer[cmdIndex] = '\0';
        processCommand(cmdBuffer);
        cmdIndex = 0;
      }
    } else if (cmdIndex < (int)(sizeof(cmdBuffer) - 1)) {
      cmdBuffer[cmdIndex++] = (char)inByte;
    } else {
      cmdIndex = 0;
    }
  }
}

// --- COMMAND PROCESSING ---
void processCommand(char *cmd) {
  int len = strlen(cmd);
  while (len > 0 && (cmd[len - 1] == ' ' || cmd[len - 1] == '\t')) {
    cmd[--len] = '\0';
  }
  for (int i = 0; cmd[i]; i++) {
    cmd[i] = toupper(cmd[i]);
  }

  if (strcmp(cmd, "OPEN") == 0) {
    openGate();
  } else if (strcmp(cmd, "CLOSE") == 0) {
    closeGate();
  } else if (strcmp(cmd, "STATUS") == 0) {
    printStatus();
  } else if (strcmp(cmd, "REBOOT") == 0) {
    Serial.println("REBOOT command received - resetting now");
    delay(100);
    hardwareReset();
  } else if (strlen(cmd) > 0) {
    Serial.print("Unknown: ");
    Serial.println(cmd);
  }
}

// --- GATE CONTROL ---
// lockGate drops the relay. Call with interrupts disabled.
void lockGate() {
  digitalWrite(relayPin, LOW);
  gateIsOpen = false;
  gateCloseTime = millis();
  if (gateCloseTime == 0) gateCloseTime = 1;
}

void openGate() {
  const char *rejected = NULL;

  noInterrupts();
  if (gateIsOpen) {
    // Already open: a duplicate OPEN must not restart the timer.
    rejected = "OPEN ignored (already open)";
  } else if (gateCloseTime > 0 && (millis() - gateCloseTime) < CLOSE_COOLDOWN_MS) {
    rejected = "OPEN ignored (cooldown active)";
  } else {
    unsigned long now = millis();
    gateOpenTime = now == 0 ? 1 : now;
    gateCloseTime = 0;
    passPending = false;
    gateIsOpen = true;
    digitalWrite(relayPin, HIGH);
  }
  interrupts();

  if (rejected) {
    Serial.println(rejected);
  } else {
    Serial.println("Gate OPENED");
  }
}

void closeGate() {
  noInterrupts();
  lockGate();
  interrupts();
  Serial.println("Gate CLOSED");
}

// --- STATUS REPORTING ---
void printStatus() {
  Serial.println("=== STATUS ===");
  Serial.print("Gate: ");
  Serial.println(gateIsOpen ? "OPEN" : "CLOSED");
  Serial.print("Switch: ");
  Serial.println(digitalRead(switchPin) ? "HIGH" : "LOW");
  Serial.println("================");
}

// --- HARDWARE SELF-RESET ---
void hardwareReset() {
  digitalWrite(resetPin, LOW);
  delay(1000);
}
