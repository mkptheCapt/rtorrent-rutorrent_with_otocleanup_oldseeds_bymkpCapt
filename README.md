# rtorrent-rutorrent + Otomatik Eski Torrent Temizleme

Docker tabanlı **rTorrent** ve **ruTorrent** kurulumu + **Otomatik eski torrent temizleme sistemi**. Türkçe rehberli, tek komutla tüm sistem kuruluyor.
Bu yazılımın amacı: Ubuntu (linux) kurulu serverda görsel arayüzlü RTorrent kurmak ve rss ile otomatik indirmesini-seed etmesini sağlamak ve 
indirip seed ettiği torrent dosyalar boyutu toplamının belli bir GB kapasiteden fazla olmamasını kontrol etmek.
Böylece rss ile herşeyi indirirken hard diskin tamamını kullanıp diski doldurmaması.
İşlev olarak torrent dosyaların indirildiği klasör düzenli kontrol ediliyor ve istediğiniz toplam GB boyuttan fazla ise
eski dosyalar ile temp dosyalar otomatik siliniyor. Böylece yeni rss torrentlerin indirilmesi için yer açılıyor diskte.

## ⚡ Hızlı Kurulum

```bash
git clone https://github.com/mkptheCapt/rtorrent-rutorrent_with_otocleanup_oldseeds_bymkpCapt.git
cd rtorrent-rutorrent_with_otocleanup_oldseeds_bymkpCapt
bash install.sh
```

## 📋 Kurulum Sırasında Sorulacaklar

1. **ruTorrent Kullanıcı Adı** (örn: admin)
2. **ruTorrent Şifre** (güvenli bir şifre gir)
3. **VPS Genel IP Adresi ve Port** (örn: 192.168.1.100:8080 veya boş bırak - otomatik tespit)
4. **Saat Dilimi** (varsayılan: Europe/Istanbul)
5. **Otocleanup maksimum boyut** (GiB cinsinden, örn: 55)
6. **Otocleanup çalışma saatleri** (virgülle ayır, örn: 6,14,22)

## ✨ Özellikler

- ✅ **Otomatik Docker Kurulumu** - Docker yoksa otomatik kurar
- ✅ **rTorrent + ruTorrent** - Modern web arayüzü
- ✅ **Şifre Koruması** - Kullanıcı adı/şifre ile güvenli erişim
- ✅ **Otomatik Eski Torrent Temizleme** - Belirtilen boyut limitine ulaşınca en eski torrentleri siler
- ✅ **Cron Job Entegrasyonu** - Günde belirlediğin saatlerde otomatik çalışır
- ✅ **WebDAV Desteği** - Tamamlanan dosyalara network erişimi
- ✅ **XMLRPC API** - Harici uygulamalardan kontrol
- ✅ **Türkçe Rehber** - Türkçe açıklamalarla tüm dosyalar
- ✅ **Help Komutu** - `help_rutorrent_bymkp` ile yararlı komutları göster

## 📂 Erişim Adresleri (Kurulum Sonrası)

```
🌐 ruTorrent Web:    http://VPS_IP:8080
🌐 WebDAV:           http://VPS_IP:9000
🌐 XMLRPC (API):     http://VPS_IP:8000
```

Kullanıcı Adı ve Şifre: Kurulum sırasında girdiğin bilgiler

## 🔧 Yararlı Komutlar

Kurulum sonrası terminalden şu komutu çalıştır:

```bash
help_rutorrent_bymkp
```

Bu komut tüm yararlı komutları listeler:
- Docker container yönetimi
- Otocleanup script'i çalıştırma
- Log izleme
- Ayar değiştirme
- Klasör konumları

## 📁 Önemli Klasörler

```
rtorrent-rutorrent_with_otocleanup_oldseeds_bymkpCapt/
├── data/               # rTorrent yapılandırması ve loglar
├── downloads/
│   ├── temp/          # İndiriliyor (tamamlanmamış)
│   └── complete/      # Tamamlanan dosyalar
├── passwd/            # Kullanıcı şifreleri (GİT'E YÜKLEME!)
└── cleanup.log        # Otocleanup log dosyası
```

## 🔒 Güvenlik Notları

⚠️ **ÖNEMLİ:**
- `.env` dosyası hassas bilgiler içerir - **GİT'E YÜKLEME!**
- `passwd/` klasörü kullanıcı şifreleri içerir - **GİT'E YÜKLEME!**
- `rtorrent-cleanup.sh` kullanıcıya özel - **GİT'E YÜKLEME!**
- `.gitignore` bu dosyaları otomatik olarak hariç tutar

## 🔄 Otomatik Temizlik Nasıl Çalışır?

1. **Belirlenen saatlerde** (örn: 06:00, 14:00, 22:00) cron job otomatik çalışır
2. **Temp klasörünü temizler** (tamamlanmamış indirmeleri siler)
3. **Complete klasöründeki toplam boyutu hesaplar** (seed edilen torrentler)
4. **Boyut limitini aşarsa** en eski torrentleri siler
5. **Limit altına düşene kadar** silmeye devam eder
6. **Log tutar** - Tüm işlemler kaydedilir

## 📊 Sistem Gereksinimleri

- Ubuntu 20.04+ veya Debian 11+
- Minimum 1GB RAM (4GB+ önerilir)
- Minimum 10GB disk (torrent boyutuna göre artır)
- Internet bağlantısı

## 🛠️ Manuel Ayarlar

### Maksimum Boyutu Değiştir

```bash
nano ~/rtorrent-cleanup.sh
# MAX_TOTAL_SIZE_GIB=55  -> İstediğin değeri yaz
```

### Temizlik Saatlerini Değiştir

```bash
crontab -e
# Saat değerlerini düzenle
```

### Manuel Temizlik Çalıştır

```bash
bash ~/rtorrent-cleanup.sh
```

## 📚 İlgili Bağlantılar (rtorrent ve rutorrent için kaynak kodları yazanlara teşekkürler)

- [rTorrent GitHub](https://github.com/rakshasa/rtorrent)
- [ruTorrent GitHub](https://github.com/Novik/ruTorrent)
- [crazy-max Docker Imajı](https://github.com/crazy-max/docker-rtorrent-rutorrent)

## 📝 Lisans

MIT License

## 🤝 Katkıda Bulun

Hataları bildir, fikirler öner: GitHub Issues'de yazabilirsin.

---

**Hazırladı:** mkptheCapt  
**Son Güncelleme:** 2025-10-22  
**Versiyon:** 2.0 (Otocleanup dahil)
