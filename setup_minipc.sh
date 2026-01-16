#!/bin/bash

###############################################################################
# Ice City Mini PC Setup Script
# Debian 13 (Trixie) uchun
# 
# Bu script Mini PC'ni turniket tizimi uchun to'liq tayyorlaydi:
# - System packages o'rnatadi
# - Docker va Git o'rnatadi
# - User permissions sozlaydi
# - Loyihani clone qiladi
# - Systemd service sozlaydi
# - Avtomatik ishga tushirishni yoqadi
###############################################################################

set -e  # Xatolikda to'xtash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/your-username/ice-city.git"
INSTALL_DIR="/home/icecity/ice-city"
SERVICE_USER="icecity"
SERVICE_FILE="/etc/systemd/system/minipc-init.service"

###############################################################################
# Helper Functions
###############################################################################

print_header() {
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║           Ice City Mini PC Setup Script                       ║"
    echo "║           Debian 13 (Trixie)                                   ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${GREEN}[$(date +%H:%M:%S)] ► $1${NC}"
}

print_info() {
    echo -e "${YELLOW}[INFO] $1${NC}"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Bu script root sifatida ishga tushirilishi kerak!"
        echo "Quyidagicha ishga tushiring: sudo bash setup_minipc.sh"
        exit 1
    fi
}

check_debian() {
    if [ ! -f /etc/debian_version ]; then
        print_error "Bu script faqat Debian uchun!"
        exit 1
    fi
    
    DEBIAN_VERSION=$(cat /etc/debian_version | cut -d. -f1)
    if [ "$DEBIAN_VERSION" -lt 13 ]; then
        print_error "Debian 13 yoki yuqori versiya talab qilinadi!"
        print_info "Hozirgi versiya: $(cat /etc/debian_version)"
        exit 1
    fi
}

###############################################################################
# Main Setup Functions
###############################################################################

step1_update_system() {
    print_step "Step 1: System'ni yangilash..."
    
    apt-get update -qq
    apt-get upgrade -y -qq
    
    print_info "✓ System yangilandi"
}

step2_install_packages() {
    print_step "Step 2: Kerakli paketlarni o'rnatish..."
    
    # Base packages
    apt-get install -y -qq \
        sudo \
        git \
        curl \
        wget \
        nano \
        vim \
        htop \
        net-tools \
        ca-certificates \
        gnupg \
        lsb-release
    
    print_info "✓ Base paketlar o'rnatildi"
}

step3_install_docker() {
    print_step "Step 3: Docker va Docker Compose o'rnatish..."
    
    # Docker o'rnatish
    apt-get install -y -qq docker.io docker-compose-v2
    
    # Docker'ni enable qilish
    systemctl enable docker
    systemctl start docker
    
    # Docker versiyasini tekshirish
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
    COMPOSE_VERSION=$(docker compose version | cut -d' ' -f4)
    
    print_info "✓ Docker $DOCKER_VERSION o'rnatildi"
    print_info "✓ Docker Compose $COMPOSE_VERSION o'rnatildi"
}

step4_configure_user() {
    print_step "Step 4: User permissions sozlash..."
    
    # User mavjudligini tekshirish
    if ! id "$SERVICE_USER" &>/dev/null; then
        print_error "User '$SERVICE_USER' topilmadi!"
        print_info "User'ni yaratish..."
        useradd -m -s /bin/bash "$SERVICE_USER"
        passwd "$SERVICE_USER"
    fi
    
    # Guruhlarga qo'shish
    usermod -aG sudo "$SERVICE_USER"
    usermod -aG docker "$SERVICE_USER"
    usermod -aG dialout "$SERVICE_USER"  # Arduino/Serial port uchun
    
    print_info "✓ User '$SERVICE_USER' guruhlarga qo'shildi: sudo, docker, dialout"
}

step5_clone_repository() {
    print_step "Step 5: Loyihani clone qilish..."
    
    # Agar papka mavjud bo'lsa, o'chirish
    if [ -d "$INSTALL_DIR" ]; then
        print_info "Eski papka topildi, o'chirilmoqda..."
        rm -rf "$INSTALL_DIR"
    fi
    
    # Git clone
    print_info "Git clone: $REPO_URL"
    sudo -u "$SERVICE_USER" git clone "$REPO_URL" "$INSTALL_DIR"
    
    # minipc_init papkasini tekshirish
    if [ ! -d "$INSTALL_DIR/minipc_init" ]; then
        print_error "minipc_init papkasi topilmadi!"
        exit 1
    fi
    
    print_info "✓ Loyiha clone qilindi: $INSTALL_DIR"
}

step6_setup_environment() {
    print_step "Step 6: Environment variables sozlash..."
    
    cd "$INSTALL_DIR/minipc_init"
    
    # .env.example'dan .env yaratish
    if [ -f ".env.example" ]; then
        if [ ! -f ".env" ]; then
            sudo -u "$SERVICE_USER" cp .env.example .env
            print_info "✓ .env fayl yaratildi (.env.example dan)"
            print_info "⚠ .env faylni tahrirlashni unutmang!"
        else
            print_info "✓ .env fayl allaqachon mavjud"
        fi
    else
        print_info "⚠ .env.example topilmadi, .env yaratilmadi"
    fi
    
    # autostart.sh'ni executable qilish
    if [ -f "autostart.sh" ]; then
        chmod +x autostart.sh
        print_info "✓ autostart.sh executable qilindi"
    else
        print_error "autostart.sh topilmadi!"
    fi
}

step7_install_systemd_service() {
    print_step "Step 7: Systemd service o'rnatish..."
    
    # Service file'ni nusxalash
    SERVICE_SOURCE="$INSTALL_DIR/minipc_init/minipc-init.service"
    
    if [ -f "$SERVICE_SOURCE" ]; then
        cp "$SERVICE_SOURCE" "$SERVICE_FILE"
        
        # Path'larni to'g'rilash (agar kerak bo'lsa)
        sed -i "s|WorkingDirectory=.*|WorkingDirectory=$INSTALL_DIR/minipc_init|g" "$SERVICE_FILE"
        sed -i "s|ExecStart=.*|ExecStart=$INSTALL_DIR/minipc_init/autostart.sh|g" "$SERVICE_FILE"
        sed -i "s|User=.*|User=$SERVICE_USER|g" "$SERVICE_FILE"
        sed -i "s|Group=.*|Group=$SERVICE_USER|g" "$SERVICE_FILE"
        
        # Systemd reload
        systemctl daemon-reload
        
        # Service'ni enable qilish
        systemctl enable minipc-init.service
        
        print_info "✓ Systemd service o'rnatildi va enable qilindi"
    else
        print_error "minipc-init.service fayl topilmadi: $SERVICE_SOURCE"
        print_info "Service o'rnatilmadi, qo'lda o'rnatish kerak"
    fi
}

step8_test_docker() {
    print_step "Step 8: Docker test..."
    
    cd "$INSTALL_DIR/minipc_init"
    
    # Docker compose file mavjudligini tekshirish
    if [ ! -f "docker-compose.yml" ]; then
        print_error "docker-compose.yml topilmadi!"
        return 1
    fi
    
    # Syntax tekshirish
    if sudo -u "$SERVICE_USER" docker compose config > /dev/null 2>&1; then
        print_info "✓ docker-compose.yml syntax to'g'ri"
    else
        print_error "docker-compose.yml'da xatolik bor!"
        return 1
    fi
}

step9_configure_serial_port() {
    print_step "Step 9: Serial port sozlash (Arduino/Turniket)..."
    
    # Serial port'larni topish
    SERIAL_PORTS=$(ls /dev/ttyUSB* /dev/ttyACM* 2>/dev/null || true)
    
    if [ -n "$SERIAL_PORTS" ]; then
        print_info "Serial port'lar topildi:"
        for port in $SERIAL_PORTS; do
            print_info "  - $port"
            # Permissions berish
            chmod 666 "$port" 2>/dev/null || true
        done
    else
        print_info "⚠ Serial port topilmadi (Arduino ulanmagan?)"
        print_info "Arduino ulanganda avtomatik taniladi"
    fi
}

step10_final_checks() {
    print_step "Step 10: Final checks..."
    
    # Docker status
    if systemctl is-active --quiet docker; then
        print_info "✓ Docker service ishlayapti"
    else
        print_error "Docker service ishlamayapti!"
    fi
    
    # Service status
    if systemctl is-enabled --quiet minipc-init.service; then
        print_info "✓ minipc-init.service enabled"
    else
        print_info "⚠ minipc-init.service enabled emas"
    fi
    
    # User guruhlari
    USER_GROUPS=$(groups "$SERVICE_USER" | cut -d: -f2)
    print_info "User '$SERVICE_USER' guruhlari:$USER_GROUPS"
}

print_summary() {
    echo ""
    echo -e "${GREEN}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                                                                ║"
    echo "║                   ✅ SETUP MUVAFFAQIYATLI!                    ║"
    echo "║                                                                ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${YELLOW}📋 KEYINGI QADAMLAR:${NC}"
    echo ""
    echo "1. .env faylni tahrirlang:"
    echo "   sudo nano $INSTALL_DIR/minipc_init/.env"
    echo ""
    echo "2. Service'ni ishga tushiring:"
    echo "   sudo systemctl start minipc-init.service"
    echo ""
    echo "3. Status tekshiring:"
    echo "   sudo systemctl status minipc-init.service"
    echo "   docker ps"
    echo ""
    echo "4. Reboot test qiling:"
    echo "   sudo reboot"
    echo ""
    echo -e "${BLUE}📍 Loyiha manzili: $INSTALL_DIR${NC}"
    echo ""
}

###############################################################################
# Main Execution
###############################################################################

main() {
    print_header
    
    # Pre-checks
    check_root
    check_debian
    
    echo ""
    print_info "Setup boshlanmoqda..."
    print_info "Repository: $REPO_URL"
    print_info "Install directory: $INSTALL_DIR"
    print_info "Service user: $SERVICE_USER"
    echo ""
    
    # Tasdiqlash
    read -p "Davom ettirilsinmi? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Setup bekor qilindi"
        exit 0
    fi
    
    echo ""
    
    # Setup steps
    step1_update_system
    step2_install_packages
    step3_install_docker
    step4_configure_user
    step5_clone_repository
    step6_setup_environment
    step7_install_systemd_service
    step8_test_docker
    step9_configure_serial_port
    step10_final_checks
    
    # Summary
    print_summary
}

# Run main function
main "$@"