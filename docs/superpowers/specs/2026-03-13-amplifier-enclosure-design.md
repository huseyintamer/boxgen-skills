# Amplifikatör Kutusu Tasarım Spesifikasyonu

## Özet

TPA3116 mono dijital amplifikatör kartı (79 × 54 × 16mm) için 3D baskıya uygun, taşınabilir kullanıma yönelik iki parçalı (tepsi + kapak) kutu tasarımı. OpenSCAD ile parametrik olarak modellenecek.

## Cihaz Bilgisi

- **Kart:** TPA3116 mono dijital amplifikatör
- **PCB boyutları:** 79 × 54 × 16mm (uzunluk × genişlik × toplam yükseklik)
  - 16mm, PCB tabanından en yüksek bileşene (soğutucu) kadar olan **toplam yüksekliktir** (bare board + bileşenler dahil)
- **Önemli bileşenler:**
  - Siyah alüminyum soğutucu (kartın üst-orta bölgesinde, en yüksek bileşen, ~30 × 25mm yüzey alanı)
  - Yeşil terminal blokları (güç girişi ve hoparlör çıkışı — kısa kenarlar boyunca, ön ve arka)
  - Elektrolitik kapasitörler (köşelerde)

## Kullanım Senaryosu

- **Taşınabilir kullanım** — sağlamlık, hafiflik ve kompakt boyut öncelikli
- Terminal bloklarına dışarıdan tam erişim gerekli

## Oryantasyon ve Eksen Tanımları

```
        Y (genişlik, 54mm)
        ↑
        │   ┌─────────────────┐
        │   │                 │
        │   │      PCB        │  ← Sol duvar (KAPALI)
        │   │                 │
        │   └─────────────────┘
        └──────────────────────→ X (uzunluk, 79mm)

  Ön (X=0): AÇIK — terminal blokları erişimi
  Arka (X=max): AÇIK — terminal blokları erişimi
  Sol (Y=0): KAPALI — duvar var
  Sağ (Y=max): KAPALI — duvar var
```

- **X ekseni:** PCB uzun kenarı boyunca (79mm)
- **Y ekseni:** PCB kısa kenarı boyunca (54mm)
- **Z ekseni:** Yükseklik (16mm PCB + standoff + boşluklar)
- **Açık yüzeyler:** Ön (X=0) ve arka (X=max) — kısa kenarlardaki 59mm genişliğindeki yüzeyler
- **Kapalı duvarlar:** Sol (Y=0) ve sağ (Y=max) — 84mm uzunluğundaki yan duvarlar

## Tasarım Yaklaşımı

**Tepsi + Kapak (2 parça)**

- **Tepsi (alt):** Taban plakası + sol/sağ yan duvarlar. Ön ve arka yüzeyler açık. PCB kenar destekleri tabanda, snap-fit klipsler yan duvarların iç yüzeyinde.
- **Kapak (üst):** Düz plaka + iç dudak. Havalandırma ızgarası soğutucu üzerinde, iç dudak üzerinde klips çengelleri.

## Boyutlar

| Parametre | Değer | Açıklama |
|-----------|-------|----------|
| PCB boyutları | 79 × 54 × 16mm | Verilen (toplam yükseklik, bileşenler dahil) |
| Duvar kalınlığı | 2mm | 3D baskı için standart |
| PCB toleransı | +0.5mm (her yön) | PCB rahat oturması için |
| Standoff yüksekliği | 2mm | PCB altı hava boşluğu |
| PCB üstü boşluk | 2mm | Bileşen + kapak arası tolerans |
| İç hacim | 80 × 55 × 20mm | PCB + tolerans + standoff + üst boşluk |
| Taban plakası | 84 × 55mm | Uzunluk: 80 + 2×2mm duvar, genişlik: iç genişlik (ön/arka açık) |
| Dış boyut (tepsi) | 84 × 59 × 20mm | Taban + 2× yan duvar kalınlığı |
| Dış boyut (kapak dahil) | 84 × 59 × 22mm | Tepsi + kapak (2mm kalınlık) |

## PCB Montaj

PCB, köşelerinden kenar desteği (ledge) ile tutulur. Bu yöntem montaj deliği gerektirmez ve çoğu PCB ile uyumludur.

- **4 adet köşe desteği** — tabana entegre L-şekilli çıkıntılar
  - PCB'nin 4 köşesini alttan ve yandan kavrar
  - Ledge genişliği: 2mm (PCB altına giren kısım)
  - Ledge yüksekliği: 2mm (standoff işlevi görür)
  - Yan duvar yüksekliği: 3mm (PCB'yi yandan hizalar)
  - PCB toleransı ledge içine dahil (+0.5mm)
- PCB köşe desteklerine oturur, kapak kapandığında hafif baskıyla yerinde kalır
- Köşe destekleri açık yüzeylerden (ön/arka) en az 2mm içeride konumlanır — açık kenara taşmaz
- Opsiyonel: Montaj deliği olan kartlar için standoff pozisyonları parametrik olarak eklenebilir

## Snap-Fit Klips Mekanizması

- **4 adet klips** — her yan duvarda (sol ve sağ, 84mm uzunluğundaki duvarlar) 2 adet, eşit aralıklı
- Klips parametreleri:
  - Genişlik: 5mm
  - Yükseklik: 3mm
  - Çengel derinliği: 1.5mm
  - Tolerans: 0.3mm (3D baskı uyumu)
- **Mekanizma:** Yan duvarların **iç yüzeyinde**, duvar üst kenarından 1mm aşağıda dikdörtgen oyuklar (recess). Kapağın iç dudağı üzerindeki dışa bakan çengeller bu oyuklara geçer.
- **Açma:** Kapağı yukarı kaldırmak — çengeller esner ve çıkar

## Kapak Tasarımı

- **Kapak plakası:** 84 × 59 × 2mm düz plaka (tepsi ile aynı dış footprint)
- **İç dudak:** Kapağın sol ve sağ kenarlarından 4mm aşağı, 1.5mm kalınlıkta, tepsi yan duvarlarının **içine** oturur
  - İç dudak uzunluğu: 80mm (iç hacim uzunluğu — ön/arka açık olduğu için tam uzunluk)
  - Dudak derinliği 4mm: klips çengeli (3mm) + üst boşluk (1mm) tam oturması için
  - Yatay kayma önlenir
  - Klips çengelleri: iç dudak üzerinde dışa bakan 4 adet küçük çıkıntı (yan duvardaki slotlara geçer)
- **Ön/arka kenarlarda dudak yok** — açık yüzeylere müdahale etmez

## Havalandırma

- **Izgara konumu:** Soğutucunun üzerine hizalı (kapak üzerinde)
  - Soğutucu tahmini merkez pozisyonu: PCB merkezinden ~5mm ön tarafa ofsetli
  - X offset (ön kenardan): ~22mm
  - Y offset (sol kenardan): ~14mm
  - Bu değerler parametrik olarak tanımlanır, gerçek kart ölçüsüne göre ayarlanabilir
- **Izgara alanı:** ~30 × 25mm
- **Desen:** 8 yatay paralel slot (kapak plakasını tam geçen through-cut delikler)
  - Slot genişliği: 1.5mm
  - Köprü genişliği: 1.5mm
- **Hava akışı:** Ön/arka açık yüzeylerden giriş → ızgaradan yukarı çıkış (doğal konveksiyon)

## OpenSCAD Dosya Yapısı

Tek dosya: `enclosure.scad`

Tüm ölçüler dosya başında değişken olarak tanımlanır (parametrik tasarım). Tüm modüller bu üst-düzey değişkenlere referans verir, modül parametresi almaz.

### Değişkenler

```
// PCB
pcb_length = 79;    // X ekseni
pcb_width = 54;     // Y ekseni
pcb_height = 16;    // Z ekseni (toplam, bileşenler dahil)
pcb_tolerance = 0.5;

// Kutu
wall_thickness = 2;
standoff_height = 2;
top_clearance = 2;

// Klips
clip_width = 5;
clip_height = 3;
clip_hook_depth = 1.5;
clip_tolerance = 0.3;

// Havalandırma
vent_x_offset = 22;   // Ön kenardan
vent_y_offset = 14;   // Sol kenardan
vent_length = 30;
vent_width = 25;
slot_width = 1.5;
bridge_width = 1.5;

// Kapak
lid_thickness = 2;
lid_lip_depth = 4;     // İç dudak aşağı inme miktarı (clip_height + clip_recess_z_from_top kadar)
lid_lip_thickness = 1.5;
```

### Modüller

- `module tray()` — taban plakası + sol/sağ yan duvarlar + PCB köşe destekleri + klips slotları
- `module lid()` — kapak plakası + iç dudak (sol/sağ) + klips çengelleri + havalandırma ızgarası
- `module print_layout()` — her iki parça yan yana, baskı yönünde yerleştirilmiş

### Baskı Modu

- Tepsi: taban aşağı (doğal pozisyon)
- Kapak: üst yüzey aşağı (düz yüzey baskı tablasında, dudak yukarı bakar)
- İki parça arası boşluk: 10mm
- Destek yapısı gerektirmez

## 3D Baskı Notları

- **Malzeme:** PLA veya PETG
- **Katman yüksekliği:** 0.2mm önerilen
- **Doluluk:** %20-30 yeterli
- **Destek:** Gerekmiyor (tasarım destek gerektirmeyecek şekilde yapılandırıldı)
