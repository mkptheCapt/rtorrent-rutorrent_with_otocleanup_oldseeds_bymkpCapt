#!/bin/bash

# ============================================================================
# rtorrent-rutorrent + Otomatik Cleanup Kurulum Scripti
# ============================================================================
# Bu script Docker, rTorrent, ruTorrent ve otomatik temizlik sistemini kurar
# ============================================================================

set -e

# Renkli çıktı için değişkenler
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# FONKSIYONLAR
# ============================================================================

print_header() {
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# ============================================================================
# KONTROLLER
# ============================================================================

print_header "Sistem Kontrolleri Yapılıyor..."

if [ "$EUID" -eq 0 ]; then 
   print_error "Bu scripti root olarak çalıştırma! (sudo kullanmadan çalıştır)"
   exit 1
fi

print_success "Root kontrolü tamam"

# ============================================================================
# DOCKER KURULUMU
# ============================================================================

if ! command -v docker &> /dev/null; then
    print_header "Docker Kurulumu Yapılıyor..."
    
    print_info "Sistem paketleri güncelleniyor..."
    sudo apt update
    sudo apt upgrade -y
    
    print_info "Gerekli paketler kuruluyor..."
    sudo apt install -y ca-certificates curl gnupg lsb-release bc
    
    print_info "Docker GPG anahtarı ekleniyor..."
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    print_info "Docker repository'si ekleniyor..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    print_info "Paket listesi güncelleniyor..."
    sudo apt update
    
    print_info "Docker Engine ve Compose kuruluyor..."
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    print_info "Docker servisi başlatılıyor..."
    sudo systemctl start docker
    sudo systemctl enable docker
    
    print_success "Docker başarıyla kuruldu"
else
    print_success "Docker zaten kurulu"
    
    # bc paketini kontrol et
    if ! command -v bc &> /dev/null; then
        print_info "bc paketi kuruluyor..."
        sudo apt install -y bc
    fi
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    print_error "Docker Compose kurulunamadı."
    exit 1
fi

print_success "Docker Compose kurulu"

# ============================================================================
# KULLANICI GİRİŞLERİ
# ============================================================================

print_header "Yapılandırma Bilgileri Girişi"

# ruTorrent kullanıcı adı
echo ""
print_info "ruTorrent Web Arayüzü için Kullanıcı Bilgileri"
read -p "Kullanıcı Adı (örn: admin): " RUTORRENT_USER
while [ -z "$RUTORRENT_USER" ]; do
    print_error "Kullanıcı adı boş olamaz!"
    read -p "Kullanıcı Adı: " RUTORRENT_USER
done

# ruTorrent şifre
read -sp "Şifre (ekranda görünmeyecek): " RUTORRENT_PASS
echo ""
while [ -z "$RUTORRENT_PASS" ]; do
    print_error "Şifre boş olamaz!"
    read -sp "Şifre: " RUTORRENT_PASS
    echo ""
done

read -sp "Şifre (tekrar - doğrulama): " RUTORRENT_PASS_CONFIRM
echo ""
while [ "$RUTORRENT_PASS" != "$RUTORRENT_PASS_CONFIRM" ]; do
    print_error "Şifreler eşleşmiyor!"
    read -sp "Şifre: " RUTORRENT_PASS
    echo ""
    read -sp "Şifre (tekrar): " RUTORRENT_PASS_CONFIRM
    echo ""
done

print_success "ruTorrent kullanıcı bilgileri kaydedildi"

# VPS IP adresi ve port
echo ""
print_info "VPS Genel IP Adresi ve Port"
print_warning "Boş bırakırsan otomatik tespit edilecek"
print_info "Örnek: 192.168.1.100:8080 veya sadece IP: 192.168.1.100"
read -p "IP:Port (Enter'a basabilirsin): " WAN_IP_PORT

if [ -z "$WAN_IP_PORT" ]; then
    print_info "IP otomatik tespit edilecek"
    WAN_IP=""
    RUTORRENT_PORT="8080"
else
    # Port ayrımı yap
    if [[ "$WAN_IP_PORT" == *":"* ]]; then
        WAN_IP=$(echo "$WAN_IP_PORT" | cut -d':' -f1)
        RUTORRENT_PORT=$(echo "$WAN_IP_PORT" | cut -d':' -f2)
    else
        WAN_IP="$WAN_IP_PORT"
        RUTORRENT_PORT="8080"
    fi
    print_success "IP: $WAN_IP, Port: $RUTORRENT_PORT"
fi

# Saat dilimi
echo ""
print_info "Saat Dilimi (varsayılan: Europe/Istanbul)"
read -p "Saat Dilimi (Enter için varsayılan): " TIMEZONE
TIMEZONE=${TIMEZONE:-Europe/Istanbul}
print_success "Saat dilimi: $TIMEZONE"

# Otomatik temizlik - maksimum boyut
echo ""
print_info "Otomatik Temizlik Ayarları"
read -p "Toplam torrent boyutu max kaç GiB olacak? (örn: 55): " MAX_SIZE_GIB
while ! [[ "$MAX_SIZE_GIB" =~ ^[0-9]+$ ]]; do
    print_error "Sadece sayı girebilirsin!"
    read -p "Toplam boyut (GiB): " MAX_SIZE_GIB
done
print_success "Maksimum boyut: ${MAX_SIZE_GIB} GiB"

# Otomatik temizlik - çalışma saatleri
echo ""
print_info "Otocleanup hangi saatlerde çalışsın?"
print_warning "Sadece saat başı yazın. Virgülle ayırın. Örnek: 6,14,22"
read -p "Saatler (örn: 6,14,22): " CLEANUP_HOURS
while [ -z "$CLEANUP_HOURS" ]; do
    print_error "En az bir saat girmelisin!"
    read -p "Saatler: " CLEANUP_HOURS
done
print_success "Temizlik saatleri: $CLEANUP_HOURS"

# ============================================================================
# KLASÖRLERIN OLUŞTURULMASI
# ============================================================================

print_header "Klasörler Oluşturuluyor..."

mkdir -p data downloads passwd
sudo chown -R 1000:1000 data downloads passwd
sudo chmod -R 755 data downloads passwd

print_success "Klasörler oluşturuldu"

# ============================================================================
# HTPASSWD DOSYALARININ OLUŞTURULMASI
# ============================================================================

print_header "Kullanıcı Adı/Şifre Dosyaları Oluşturuluyor..."

print_info "ruTorrent Web Arayüzü için..."
sudo docker run --rm httpd:2.4-alpine htpasswd -Bbn "$RUTORRENT_USER" "$RUTORRENT_PASS" | sudo tee passwd/rutorrent.htpasswd > /dev/null
print_success "rutorrent.htpasswd oluşturuldu"

print_info "XMLRPC API için..."
sudo docker run --rm httpd:2.4-alpine htpasswd -Bbn "$RUTORRENT_USER" "$RUTORRENT_PASS" | sudo tee passwd/rpc.htpasswd > /dev/null
print_success "rpc.htpasswd oluşturuldu"

print_info "WebDAV için..."
sudo docker run --rm httpd:2.4-alpine htpasswd -Bbn "$RUTORRENT_USER" "$RUTORRENT_PASS" | sudo tee passwd/webdav.htpasswd > /dev/null
print_success "webdav.htpasswd oluşturuldu"

sudo chown 1000:1000 passwd/*.htpasswd
sudo chmod 600 passwd/*.htpasswd

print_success "Tüm htpasswd dosyaları oluşturuldu"

# ============================================================================
# .env DOSYASININ OLUŞTURULMASI
# ============================================================================

print_header ".env Dosyası Oluşturuluyor..."

cat > .env << EOF
RUTORRENT_USER=$RUTORRENT_USER
RUTORRENT_PASS=$RUTORRENT_PASS
WAN_IP=$WAN_IP
TIMEZONE=$TIMEZONE
CREATED_AT=$(date)
EOF

chmod 600 .env
print_success ".env dosyası oluşturuldu"

# ============================================================================
# CLEANUP SCRİPTİNİN OLUŞTURULMASI
# ============================================================================

print_header "Otomatik Temizlik Scripti Oluşturuluyor..."

# Mevcut dizini al
CURRENT_DIR=$(pwd)

cat > ~/rtorrent-cleanup.sh << 'EOFSCRIPT'
#!/bin/bash

set -e

MAX_TOTAL_SIZE_GIB=__MAX_SIZE__
DOWNLOADS_DIR="__CURRENT_DIR__/downloads"
LOG_FILE="__CURRENT_DIR__/cleanup.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_message() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_info() {
    log_message "${BLUE}ℹ $1${NC}"
}

log_success() {
    log_message "${GREEN}✓ $1${NC}"
}

log_warning() {
    log_message "${YELLOW}⚠ $1${NC}"
}

gib_to_bytes() {
    echo $(($1 * 1024 * 1024 * 1024))
}

bytes_to_gib() {
    echo "scale=2; $1 / 1024 / 1024 / 1024" | bc
}

log_info "═══════════════════════════════════════════════════════"
log_info "rTorrent Otomatik Temizlik Başlatıldı"
log_info "═══════════════════════════════════════════════════════"

# Temp klasörünü temizle
log_info "Temp klasörü temizleniyor..."
TEMP_DIR="$DOWNLOADS_DIR/temp"

if [ -d "$TEMP_DIR" ]; then
    TEMP_COUNT=$(find "$TEMP_DIR" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
    
    if [ "$TEMP_COUNT" -gt 0 ]; then
        TEMP_SIZE_BYTES=$(du -sb "$TEMP_DIR" 2>/dev/null | awk '{print $1}')
        TEMP_SIZE_GIB=$(bytes_to_gib $TEMP_SIZE_BYTES)
        
        log_info "  Temp klasöründe $TEMP_COUNT dosya bulundu (${TEMP_SIZE_GIB} GiB)"
        rm -rf "$TEMP_DIR"/*
        log_success "Temp klasörü temizlendi"
    else
        log_info "  Temp klasörü zaten boş"
    fi
fi

# Seed edilen torrentleri hesapla
log_info "Seed edilen torrentler hesaplanıyor..."

COMPLETE_DIR="$DOWNLOADS_DIR/complete"

if [ ! -d "$COMPLETE_DIR" ]; then
    log_warning "Complete klasörü bulunamadı"
    exit 0
fi

declare -A TORRENT_SIZES
declare -A TORRENT_DATES
TOTAL_SIZE_BYTES=0

for item in "$COMPLETE_DIR"/*; do
    if [ ! -e "$item" ]; then
        continue
    fi
    
    ITEM_NAME=$(basename "$item")
    
    if [ -d "$item" ]; then
        SIZE_BYTES=$(du -sb "$item" 2>/dev/null | awk '{print $1}')
    else
        SIZE_BYTES=$(stat -c %s "$item" 2>/dev/null || echo 0)
    fi
    
    CREATED_DATE=$(stat -c %Y "$item" 2>/dev/null || echo 0)
    
    TORRENT_SIZES["$ITEM_NAME"]=$SIZE_BYTES
    TORRENT_DATES["$ITEM_NAME"]=$CREATED_DATE
    TOTAL_SIZE_BYTES=$((TOTAL_SIZE_BYTES + SIZE_BYTES))
    
    SIZE_GIB=$(bytes_to_gib $SIZE_BYTES)
    log_info "  $ITEM_NAME: ${SIZE_GIB} GiB"
done

TORRENT_COUNT=${#TORRENT_SIZES[@]}

if [ "$TORRENT_COUNT" -eq 0 ]; then
    log_warning "Hiç torrent bulunamadı"
    exit 0
fi

TOTAL_SIZE_GIB=$(bytes_to_gib $TOTAL_SIZE_BYTES)
log_info "─────────────────────────────────────────────────────"
log_info "Toplam Seed Edilen: $TORRENT_COUNT torrent"
log_info "Toplam Boyut: ${TOTAL_SIZE_GIB} GiB"
log_info "Maksimum Limit: ${MAX_TOTAL_SIZE_GIB} GiB"
log_info "─────────────────────────────────────────────────────"

MAX_SIZE_BYTES=$(gib_to_bytes $MAX_TOTAL_SIZE_GIB)

if [ "$TOTAL_SIZE_BYTES" -le "$MAX_SIZE_BYTES" ]; then
    log_success "Toplam boyut limit altında. Temizlik gerekmedi."
    exit 0
fi

log_warning "Toplam boyut ${MAX_TOTAL_SIZE_GIB} GiB limitini aştı!"
log_info "En eski torrentler silinecek..."

SORTED_ITEMS=$(for item_name in "${!TORRENT_DATES[@]}"; do
    echo "${TORRENT_DATES[$item_name]} $item_name"
done | sort -n | awk '{$1=""; print substr($0,2)}')

DELETED_COUNT=0

while IFS= read -r ITEM_NAME; do
    if [ "$TOTAL_SIZE_BYTES" -le "$MAX_SIZE_BYTES" ]; then
        log_success "Toplam boyut limite düştü. Temizlik tamamlandı."
        break
    fi
    
    SIZE_BYTES=${TORRENT_SIZES["$ITEM_NAME"]}
    SIZE_GIB=$(bytes_to_gib $SIZE_BYTES)
    
    CREATED_DATE_STR=$(date -d "@${TORRENT_DATES[$ITEM_NAME]}" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "Bilinmiyor")
    log_warning "Siliniyor: $ITEM_NAME (${SIZE_GIB} GiB, Tarih: $CREATED_DATE_STR)"
    
    ITEM_PATH="$COMPLETE_DIR/$ITEM_NAME"
    
    if [ -e "$ITEM_PATH" ]; then
        rm -rf "$ITEM_PATH"
        log_info "  Diskten silindi"
    fi
    
    TOTAL_SIZE_BYTES=$((TOTAL_SIZE_BYTES - SIZE_BYTES))
    DELETED_COUNT=$((DELETED_COUNT + 1))
    
    sleep 1
done <<< "$SORTED_ITEMS"

NEW_TOTAL_SIZE_GIB=$(bytes_to_gib $TOTAL_SIZE_BYTES)
log_info "═══════════════════════════════════════════════════════"
log_success "Temizlik tamamlandı"
log_info "Silinen: $DELETED_COUNT torrent"
log_info "Yeni boyut: ${NEW_TOTAL_SIZE_GIB} GiB"
log_info "═══════════════════════════════════════════════════════"

sudo docker restart rtorrent-rutorrent > /dev/null 2>&1
log_success "ruTorrent yenilendi"
EOFSCRIPT

# Placeholder'ları değiştir
sed -i "s|__MAX_SIZE__|$MAX_SIZE_GIB|g" ~/rtorrent-cleanup.sh
sed -i "s|__CURRENT_DIR__|$CURRENT_DIR|g" ~/rtorrent-cleanup.sh

chmod +x ~/rtorrent-cleanup.sh
print_success "Cleanup scripti oluşturuldu: ~/rtorrent-cleanup.sh"

# ============================================================================
# CRON JOB KURULUMU
# ============================================================================

print_header "Cron Job Kuruluyor..."

# Mevcut crontab'ı al
crontab -l > /tmp/current_crontab 2>/dev/null || echo "" > /tmp/current_crontab

# Yeni cron job'ları ekle
echo "" >> /tmp/current_crontab
echo "# rTorrent otomatik temizlik - Yapılandırıldı: $(date)" >> /tmp/current_crontab

IFS=',' read -ra HOURS <<< "$CLEANUP_HOURS"
for hour in "${HOURS[@]}"; do
    # Boşlukları temizle
    hour=$(echo "$hour" | xargs)
    echo "0 $hour * * * /bin/bash $HOME/rtorrent-cleanup.sh >> $CURRENT_DIR/cleanup.log 2>&1" >> /tmp/current_crontab
done

crontab /tmp/current_crontab
rm /tmp/current_crontab

print_success "Cron job kuruldu (Saatler: $CLEANUP_HOURS)"

# ============================================================================
# DOCKER SERVİSLERİNİ BAŞLAT
# ============================================================================

print_header "Docker Servisleri Başlatılıyor..."

print_info "İlk çalıştırma (imaj indirilebilir, biraz zaman alabilir)..."
sudo docker compose up -d

sleep 10

if sudo docker compose ps | grep -q "rtorrent-rutorrent"; then
    print_success "Container başarıyla başlatıldı"
else
    print_error "Container başlatılamadı!"
    exit 1
fi

if sudo ss -tulpn 2>/dev/null | grep -q ":${RUTORRENT_PORT:-8080}"; then
    print_success "Port ${RUTORRENT_PORT:-8080} aktif"
fi

# ============================================================================
# HELP KOMUTU OLUŞTUR
# ============================================================================

print_header "Help Komutu Oluşturuluyor..."

cat > ~/.bashrc_rutorrent_help << 'EOFHELP'
function help_rutorrent_bymkp() {
    echo -e "\033[0;34m════════════════════════════════════════════════════════\033[0m"
    echo -e "\033[0;34mrTorrent + ruTorrent + Otocleanup - Yararlı Komutlar\033[0m"
    echo -e "\033[0;34m════════════════════════════════════════════════════════\033[0m"
    echo ""
    echo -e "\033[1;33mR-Ru/Torrent için Yararlı Komutlar:\033[0m"
    echo -e "  \033[0;32msudo docker compose logs -f\033[0m"
    echo -e "    Logları canlı izle"
    echo ""
    echo -e "  \033[0;32msudo docker compose ps\033[0m"
    echo -e "    Container durumunu kontrol et"
    echo ""
    echo -e "  \033[0;32msudo docker compose stop\033[0m"
    echo -e "    Servisleri durdur"
    echo ""
    echo -e "  \033[0;32msudo docker compose start\033[0m"
    echo -e "    Servisleri başlat"
    echo ""
    echo -e "  \033[0;32msudo docker compose restart\033[0m"
    echo -e "    Servisleri yeniden başlat"
    echo ""
    echo -e "\033[1;33mOtocleanup için Yararlı Komutlar:\033[0m"
    echo -e "  \033[0;32mcrontab -l\033[0m"
    echo -e "    Cron job durumunu kontrol et"
    echo ""
    echo -e "  \033[0;32mbash ~/rtorrent-cleanup.sh\033[0m"
    echo -e "    Script'i manuel çalıştır"
    echo ""
    echo -e "  \033[0;32mtail -f $(pwd)/cleanup.log\033[0m"
    echo -e "    Log'u canlı izle (Ctrl+C ile çık)"
    echo ""
    echo -e "  \033[0;32mnano ~/rtorrent-cleanup.sh\033[0m"
    echo -e "    Maksimum limiti değiştir (MAX_TOTAL_SIZE_GIB satırını düzenle)"
    echo ""
    echo -e "  \033[0;32mcrontab -e\033[0m"
    echo -e "    Otocleanup saatlerini değiştir"
    echo ""
    echo -e "\033[1;33mTorrent Dosyalarının Kaydedildiği Klasörler:\033[0m"
    echo -e "  $(pwd)/data/               # rTorrent yapılandırması ve loglar"
    echo -e "  $(pwd)/downloads/temp/     # İndiriliyor (tamamlanmamış)"
    echo -e "  $(pwd)/downloads/complete/ # Tamamlanan dosyalar"
    echo -e "  $(pwd)/passwd/             # Kullanıcı şifreleri (GitHub'a YÜKLEME!)"
    echo ""
    echo -e "\033[0;34m════════════════════════════════════════════════════════\033[0m"
}

alias help_rutorrent_bymkp='help_rutorrent_bymkp'
EOFHELP

# bashrc'ye ekle
if ! grep -q "source ~/.bashrc_rutorrent_help" ~/.bashrc; then
    echo "" >> ~/.bashrc
    echo "# rTorrent help komutu" >> ~/.bashrc
    echo "source ~/.bashrc_rutorrent_help" >> ~/.bashrc
fi

source ~/.bashrc_rutorrent_help

print_success "Help komutu oluşturuldu: help_rutorrent_bymkp"

# ============================================================================
# ÖZET VE SONUÇ
# ============================================================================

print_header "✓ KURULUM TAMAMLANDI"

echo ""
echo -e "${GREEN}🎉 rtorrent-rutorrent + Otocleanup başarıyla kuruldu!${NC}"
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}ERİŞİM BİLGİLERİ${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"

if [ -n "$WAN_IP" ]; then
    echo -e "🌐 Web Arayüzü: ${GREEN}http://$WAN_IP:${RUTORRENT_PORT}${NC}"
else
    DETECTED_IP=$(hostname -I | awk '{print $1}')
    echo -e "🌐 Web Arayüzü: ${GREEN}http://$DETECTED_IP:${RUTORRENT_PORT}${NC}"
fi

echo -e "👤 Kullanıcı Adı: ${GREEN}$RUTORRENT_USER${NC}"
echo -e "🔐 Şifre: ${GREEN}(girdiğin şifre)${NC}"

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}OTOMATİK TEMİZLİK AYARLARI${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════${NC}"
echo -e "📊 Maksimum Boyut: ${GREEN}${MAX_SIZE_GIB} GiB${NC}"
echo -e "⏰ Çalışma Saatleri: ${GREEN}${CLEANUP_HOURS}${NC}"
echo -e "📝 Log Dosyası: ${GREEN}$CURRENT_DIR/cleanup.log${NC}"

echo ""
echo -e "${GREEN}Yararlı komutları görmek için:${NC}"
echo -e "  ${YELLOW}help_rutorrent_bymkp${NC}"
echo ""
