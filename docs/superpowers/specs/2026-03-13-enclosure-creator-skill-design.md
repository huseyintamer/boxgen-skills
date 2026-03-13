# Enclosure Creator Skill — Tasarım Spesifikasyonu

## Özet

Claude Code için multi-skill pipeline: kullanıcıların soru-cevap akışıyla 3D baskıya hazır elektronik cihaz kutuları (enclosure) tasarlamasını sağlar. Üç bağımsız skill zincir halinde çalışır. Çıktı: parametrik OpenSCAD kodu + STL + PNG önizleme.

## Kapsam

- **Sadece kutular/enclosure** — elektronik cihaz kutuları, PCB enclosure'ları
- Organik şekiller, mekanik parçalar, braketler kapsam dışı
- Desteklenen kutu tipleri: tepsi+kapak (snap-fit), vidalı kutu, sürgülü kapak, clamshell

### Fazlama

- **Faz 1 (bu spec):** Core altyapı (3 skill.md, manufacturing.md, extras.md) + sadece `tray-lid` şablonu
- **Faz 2 (ayrı spec):** `screw-box`, `sliding-lid`, `clamshell` şablonları eklenir

Bu spec Faz 1'i kapsar. Faz 2 şablonları ayrı bir spec+plan döngüsüyle eklenecektir.

## Mimari: Multi-Skill Pipeline

```
Kullanıcı: /enclosure-params
        ↓
[Skill 1: enclosure-params]
  • Soru-cevap ile parametre toplama
  • Çıktı: enclosure-spec.json
        ↓ (otomatik zincirleme)
[Skill 2: enclosure-generate]
  • JSON'dan OpenSCAD kod üretimi
  • Şablon referansları kullanır
  • Çıktı: enclosure.scad
        ↓ (otomatik zincirleme)
[Skill 3: enclosure-validate]
  • OpenSCAD CLI ile render + hata kontrolü
  • Hata varsa → kodu düzeltir ve tekrar render (max 5)
  • Çıktı: STL + PNG önizlemeler
        ↓
Kullanıcıya teslim
```

### Skill Zincirleme Mekanizması

Her skill'in `skill.md` dosyasının sonunda bir **zincirleme talimatı** bulunur. Bu talimat Claude'a bir sonraki skill'i Skill tool ile invoke etmesini söyler:

- `enclosure-params/skill.md` sonu: `"Parametre toplama tamamlandı. Şimdi Skill tool ile enclosure-generate skill'ini invoke et."`
- `enclosure-generate/skill.md` sonu: `"Kod üretimi tamamlandı. Şimdi Skill tool ile enclosure-validate skill'ini invoke et."`
- `enclosure-validate/skill.md` sonu: Zincirleme yok — kullanıcıya son rapor gösterilir.

Bu mekanizma Claude'un doğal Skill tool çağrısını kullanır. Kullanıcı her skill'i bağımsız olarak da çağırabilir.

### Veri Köprüsü: enclosure-spec.json

Skill'ler arası veri aktarımı projenin kök dizininde oluşturulan bir JSON dosyası üzerinden yapılır.

#### Tam JSON Şeması

```json
{
  "type": "tray-lid | screw-box | sliding-lid | clamshell",

  "device": {
    "length": 79,
    "width": 54,
    "height": 16
  },

  "wall_thickness": 2,
  "tolerance": 0.5,

  "mounting": "corner-supports | standoff | edge-rail | none",

  "open_faces": ["front", "back"],

  "ventilation": {
    "enabled": true,
    "position": "top | side",
    "length": 30,
    "width": 25
  },

  "extras": {
    "cable_hole": {
      "enabled": false,
      "diameter": 6,
      "face": "back"
    },
    "label_area": {
      "enabled": false,
      "face": "top",
      "length": 40,
      "width": 20
    },
    "mounting_ear": {
      "enabled": false,
      "hole_diameter": 4,
      "ear_width": 10
    }
  }
}
```

#### Yüzey Adları (Canonical Face Enumeration)

Tüm yüzey referansları için kullanılan standart isimler:

| Yüzey | Açıklama | Geçerli kullanım |
|-------|----------|------------------|
| `top` | Üst yüzey (Z=max) | ventilation, label_area |
| `bottom` | Alt yüzey (Z=0) | label_area |
| `front` | Ön yüzey (X=0) | open_faces, cable_hole, label_area |
| `back` | Arka yüzey (X=max) | open_faces, cable_hole, label_area |
| `left` | Sol yüzey (Y=0) | cable_hole, label_area |
| `right` | Sağ yüzey (Y=max) | cable_hole, label_area |

- `mounting_ear`: Her zaman sol+sağ kapalı duvarlara eklenir (kullanıcı yüzey seçmez)
- `cable_hole`: Sadece kapalı yüzeylere eklenebilir (açık yüzey seçilirse uyarı)
- `label_area`: Herhangi bir kapalı yüzeye eklenebilir

#### Alan Açıklamaları

| Alan | Tip | Açıklama |
|------|-----|----------|
| `type` | string | Kutu tipi. Faz 1'de sadece `tray-lid` |
| `device.length` | number (mm) | Cihaz uzunluğu (X ekseni) |
| `device.width` | number (mm) | Cihaz genişliği (Y ekseni) |
| `device.height` | number (mm) | Cihaz toplam yüksekliği (bileşenler dahil, Z ekseni) |
| `wall_thickness` | number (mm) | Duvar kalınlığı. Varsayılan: 2. Min: 1.2 |
| `tolerance` | number (mm) | PCB toleransı (her yön). Sabit: 0.5. Kullanıcıya sorulmaz |
| `mounting` | string | PCB montaj tipi |
| `open_faces` | string[] | Açık bırakılacak yüzeyler. Boş dizi = tüm yüzeyler kapalı |
| `ventilation.enabled` | boolean | Havalandırma gerekli mi |
| `ventilation.position` | string | Izgara pozisyonu |
| `ventilation.length` | number (mm) | Izgara uzunluğu (X ekseni boyunca) |
| `ventilation.width` | number (mm) | Izgara genişliği (Y ekseni boyunca) |
| `extras.cable_hole` | object | Kablo geçiş deliği. `diameter`: delik çapı mm, `face`: hangi yüzeyde |
| `extras.label_area` | object | Etiket alanı. `face`: yüzey, `length`/`width`: alan boyutları mm |
| `extras.mounting_ear` | object | Montaj kulağı. `hole_diameter`: vida deliği, `ear_width`: kulak genişliği mm |

**Not:** `tolerance` sabit 0.5mm olarak kullanılır ve kullanıcıya sorulmaz. Bu değer 3D baskıda standart PCB toleransıdır.

## Skill 1: enclosure-params

### Sorumluluk

Kullanıcıyla soru-cevap akışıyla tüm kutu parametrelerini toplar, doğrular ve `enclosure-spec.json` dosyasına yazar.

### Soru Akışı (Sıralı)

Her soru AskUserQuestion tool'u ile sorulur. Multiple choice tercih edilir.

1. **Cihaz boyutları** — uzunluk × genişlik × yükseklik (mm)
   - Açık uçlu soru, kullanıcı ölçüleri girer
   - Yüksekliğin toplam yükseklik (bileşenler dahil) olduğu teyit edilir

2. **Kutu tipi** — seçenekler (Faz 1'de sadece tray-lid aktif):
   - `tray-lid`: Tepsi + kapak, snap-fit klipsler. 3D baskı için ideal, vidasız.
   - `screw-box`: 4 köşeden M3 vidayla sabitlenen kapak. (Faz 2)
   - `sliding-lid`: Kapak ray üzerinde kayar. (Faz 2)
   - `clamshell`: Üst ve alt yarım birbirine geçer. (Faz 2)

3. **Açık yüzeyler** — çoklu seçim:
   - Ön, arka, her ikisi, hiçbiri
   - Terminal blokları, konnektörler için erişim gerekiyorsa

4. **Havalandırma** — gerekli mi?
   - Hayır → `ventilation.enabled = false`, atla
   - Evet → pozisyon sorusu (üst/yan)
   - Evet → alan boyutu sorusu: "Havalandırma ızgarası ne kadar büyük olmalı? (uzunluk × genişlik mm)"
     - `top` pozisyonu varsayılan: device.length × %40, device.width × %40
     - `side` pozisyonu varsayılan: device.length × %40, inner_height × %40 (inner_height = standoff + device.height + clearance)

5. **PCB montaj tipi** — 4 seçenek:
   - Köşe desteği (L-şekilli ledge, vidasız)
   - Standoff (silindirik ayak, opsiyonel vida)
   - Kenar rayı (PCB kayarak oturur)
   - Yok (PCB serbest)

6. **Duvar kalınlığı** — varsayılan 2mm
   - Kullanıcı değiştirebilir (min 1.2mm uyarısı)

7. **Ek özellikler** — çoklu seçim (opsiyonel):
   - Kablo geçiş deliği → seçilirse: çap (varsayılan 6mm) ve yüzey (front/back/left/right)
   - Etiket alanı (düz yüzey) → seçilirse: yüzey ve boyut (varsayılan 40×20mm)
   - Montaj kulağı (duvara/panele) → seçilirse: delik çapı (varsayılan 4mm)
   - Hiçbiri

### Çıktı

Tüm sorular cevaplandıktan sonra:
1. Kullanıcıya parametre özeti gösterilir
2. Onay alınır
3. `enclosure-spec.json` projenin kök dizinine yazılır
4. Zincirleme: Claude, Skill tool ile `enclosure-generate` invoke eder

### Doğrulama Kuralları

- Boyutlar pozitif sayı olmalı
- Duvar kalınlığı ≥ 1.2mm (1.2-2mm arası uyarı verilir)
- Havalandırma alanı cihaz boyutlarından büyük olamaz
- Açık yüzey seçilmişse o yönde havalandırma anlamsız — uyarı
- Kablo deliği çapı 2-20mm arası

## Skill 2: enclosure-generate

### Sorumluluk

`enclosure-spec.json` dosyasını okur, kutu tipine uygun şablon referansını kullanarak tam parametrik OpenSCAD kodu üretir.

### Çalışma Akışı

1. `enclosure-spec.json` oku ve doğrula (dosya yoksa hata)
2. `type` alanına göre ilgili şablon referansını yükle:
   - `tray-lid` → `templates/tray-lid.md`
   - (Faz 2: `screw-box` → `templates/screw-box.md`, vb.)
3. `manufacturing.md` ortak kısıtları yükle
4. `extras.md` ek özellik referansını yükle (extras varsa)
5. Spec parametreleri + şablon yapısı + kısıtları birleştirerek OpenSCAD kodu üret
6. `enclosure.scad` dosyasına yaz
7. Zincirleme: Claude, Skill tool ile `enclosure-validate` invoke eder

### Şablon Referans Dosyaları

Her `templates/*.md` dosyası şunları içerir:

- **Modül yapısı** — hangi modüller olmalı ve sorumlulukları
- **Boyut hesaplama kuralları** — iç/dış derivasyonlar, tolerans ekleme
- **Mekanizma detayları** — o tipe özel (klips boyutları, vida pozisyonları, ray ölçüleri, geçme toleransları)
- **OpenSCAD kod iskelet örneği** — modül imzaları ve temel yapı
- **Tipe özel baskı kısıtları** — destek gereksinimleri, yönlendirme notları

#### tray-lid.md Kapsamı (Faz 1)
- Tepsi: taban + yan duvarlar (açık yüzeyler hariç)
- Kapak: düz plaka + iç dudak
- Snap-fit klips: 4 adet, duvar iç yüzeyinde oyuk + kapak dudağında çengel
- Klips parametreleri: genişlik 5mm, yükseklik 3mm, çengel 1.5mm, tolerans 0.3mm
- İç dudak derinliği: clip_height + recess_z_from_top (genelde 4mm)
- **Havalandırma pozisyonları:**
  - `top`: Kapak üzerinde yatay slotlar (varsayılan, ana kullanım)
  - `side`: Sol ve sağ yan duvarlarda yatay slotlar. Her iki kapalı duvara simetrik olarak eklenir. Slot yönü X ekseni boyunca, slot alanı duvarın iç yüksekliğinin üst %60'ında konumlanır (soğuk hava alttan, sıcak hava üstten çıkar)

#### screw-box.md Kapsamı (Faz 2)
- Alt kutu: taban + 4 duvar (açık yüzeyler hariç) + köşe vida bosları
- Üst kapak: plaka + kenar dudağı + vida delikleri
- Vida bosu: M3 için iç çap 2.5mm (self-tap) veya 3.2mm (somun), dış çap 6mm
- 4 köşe vida pozisyonu

#### sliding-lid.md Kapsamı (Faz 2)
- Kutu: taban + 3 duvar + sol/sağ duvarlarda iç ray
- Kapak: plaka, ray genişliğinde kenar çıkıntıları
- Ray: 1.5mm genişlik, 1.5mm derinlik, 0.3mm tolerans
- Kapak ön taraftan kayarak girer, opsiyonel durdurma tırnağı

#### clamshell.md Kapsamı (Faz 2)
- Alt yarım: taban + yarım yükseklikte duvarlar + kenar dudağı (dışa)
- Üst yarım: taban (ters) + yarım yükseklikte duvarlar + kenar dudağı (içe)
- Geçme toleransı: 0.3mm
- Dudak derinliği: 2mm

### extras.md — Ek Özellikler Referansı

Tüm kutu tipleri için geçerli, kutu tipinden bağımsız ek özellik referansı:

#### Kablo Geçiş Deliği
- Belirtilen yüzeyde silindirik delik (difference ile)
- Delik pozisyonu: yüzeyin merkezinde, Z olarak PCB yüksekliğinin ortasında
- Delik çapına +0.3mm tolerans eklenir
- Açık yüzeyde kablo deliği anlamsız — atlanır

#### Etiket Alanı
- Belirtilen yüzeyde sığ girinti (0.5mm derinlik)
- Etiket yapıştırma için düz yüzey oluşturur
- Pozisyon: yüzeyin merkezinde

#### Montaj Kulağı
- Sol ve sağ duvarlarda dışa taşan flanş
- Kulak genişliği parametrik, yükseklik = duvar kalınlığı
- Merkez deliği: belirtilen çap, vida geçmesi için
- Sadece kapalı duvarlara eklenir

### manufacturing.md — Ortak 3D Baskı Kısıtları

Tüm kutu tipleri için geçerli kurallar:

- Minimum duvar kalınlığı: 2mm (mutlak minimum 1.2mm)
- Delik toleransı: +0.3mm çap
- Alt kenar: chamfer kullan (fillet değil, yatak yapışması için)
- Köprü (bridge) span: max 20mm
- Overhang: max 45°
- Destek yapısı gerektirmeyecek şekilde tasarla
- Katman yüksekliği: 0.2mm varsayılan
- Tüm ölçüler dosya başında değişken olarak tanımlanır
- `print_layout()` modülü: parçalar yan yana, düz yüzeyler tablada
- `assembly()` modülü: montaj önizlemesi

### Kod Üretim Kuralları

- Claude şablonu referans alarak kodu **sıfırdan üretir** (kopyala-yapıştır değil)
- Spec'teki her özellik (açık yüzeyler, havalandırma, montaj tipi, ek özellikler) koda entegre edilir
- Tüm parametreler dosya başında değişken
- Modüller parametre almaz, üst-düzey değişkenleri kullanır
- Render mode seçici dosya sonunda (print_layout, assembly, tek parça)
- Yorum dili: İngilizce

## Skill 3: enclosure-validate

### Sorumluluk

Üretilen OpenSCAD kodunu CLI ile doğrular, hataları iteratif olarak düzeltir, STL ve PNG çıktıları üretir.

### Ön Koşul

OpenSCAD CLI erişilebilir olmalı. Kontrol:
```bash
which openscad || ls /Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD
```
Bulunamazsa kullanıcıya uyarı verir, sadece `.scad` teslim eder, STL/PNG adımlarını atlar.

### Doğrulama Döngüsü

```
enclosure.scad oku
      ↓
openscad --hardwarnings -o /dev/null enclosure.scad 2>&1
      ↓
  Hata var mı?
      │
      ├─ Evet → Hata mesajını analiz et → Kodu düzelt → Tekrar render
      │         (max 5 iterasyon, aşılırsa kullanıcıya rapor)
      │
      └─ Hayır → Export aşamasına geç
```

### Hata Düzeltme Kuralları

- **Syntax hatası**: Hata mesajındaki satır numarası ve açıklamayı okur, ilgili satırı düzeltir
- **Warning** (`--hardwarnings`): Aynı şekilde düzeltilir
- **Boş STL** (0 byte): Geometri hatası — modül çağrılarını ve boolean operasyonları inceler
- **Non-manifold uyarısı**: Kesişen veya açık geometrileri düzeltir
- Her iterasyonda yapılan değişiklik loglanır

### Export Aşaması

Doğrulama başarılı olduktan sonra:

```bash
# STL export — print layout (tüm parçalar tek dosya)
openscad -o enclosure.stl enclosure.scad

# PNG önizlemeler (4 görünüm, 1024x768)
# --autocenter --viewall kullanılır (kamera mesafesini otomatik ayarlar)
openscad -o enclosure-iso.png --imgsize 1024,768 --autocenter --viewall \
  --projection perspective enclosure.scad

openscad -o enclosure-front.png --imgsize 1024,768 --autocenter --viewall \
  --camera 0,0,0,0,0,0 --projection ortho enclosure.scad

openscad -o enclosure-top.png --imgsize 1024,768 --autocenter --viewall \
  --camera 0,0,0,90,0,0 --projection ortho enclosure.scad

openscad -o enclosure-side.png --imgsize 1024,768 --autocenter --viewall \
  --camera 0,0,0,0,0,90 --projection ortho enclosure.scad
```

**Not:** `--autocenter --viewall` kamera mesafesini otomatik ayarlar, bu yüzden explicit mesafe değeri verilmez. Ortografik görünümlerde `--projection ortho`, izometrik'te `perspective` kullanılır.

### Boyut Doğrulama (Opsiyonel)

OpenSCAD'in `echo()` fonksiyonu kullanılarak bounding box kontrolü yapılır. Üretilen kodun sonuna geçici olarak eklenir:

```openscad
// Temporary bounding box check
echo("BBOX_X", outer_length);
echo("BBOX_Y", outer_width);
echo("BBOX_Z", tray_height + lid_thickness);
```

`openscad -o /dev/null enclosure.scad 2>&1` çıktısından `ECHO:` satırları parse edilir ve spec boyutlarıyla karşılaştırılır. Kontrol sonrası geçici echo satırları kaldırılır.

Beklenen dış boyut ±1mm tolerans içinde olmalı. Sapma varsa kullanıcıya rapor edilir. OpenSCAD yoksa bu adım atlanır.

### Çıktı Dosyaları

```
enclosure.scad          — OpenSCAD kaynak kodu (parametrik)
enclosure.stl           — 3D baskıya hazır STL (print layout, tüm parçalar)
enclosure-iso.png       — İzometrik önizleme (perspective)
enclosure-front.png     — Ön görünüm (ortho)
enclosure-top.png       — Üst görünüm (ortho)
enclosure-side.png      — Yan görünüm (ortho)
```

### Son Rapor

Kullanıcıya gösterilen özet:
- Kutu tipi ve boyutları
- Üretilen dosya listesi
- Doğrulama sonucu (hata sayısı, iterasyon sayısı)
- PNG önizleme (izometrik — Read tool ile gösterilir)
- Baskı önerileri (malzeme, katman yüksekliği, doluluk)

## Dosya Yapısı

```
skills/
  enclosure-params/
    skill.md                — Parametre toplama skill tanımı + soru akışı
  enclosure-generate/
    skill.md                — Kod üretimi skill tanımı + üretim kuralları
    templates/
      tray-lid.md           — Tepsi + snap-fit kapak referansı (Faz 1)
    extras.md               — Ek özellikler referansı (kablo deliği, etiket, kulak)
    manufacturing.md        — 3D baskı kısıtları (tüm tipler için ortak)
  enclosure-validate/
    skill.md                — Doğrulama + export skill tanımı
```

## Kapsam Dışı (YAGNI)

- Görsel/fotoğraf analizi
- Çoklu cihaz/multi-PCB desteği
- Menteşeli kapak mekanizması
- Organik şekiller
- BOSL2 kütüphane entegrasyonu (gelecekte eklenebilir)
- Web UI veya API
- Cihaz veritabanı/kütüphanesi
- Ayrı STL dosyaları (tek combined STL yeterli, kullanıcı slicerda ayırabilir)
- Faz 2 kutu tipleri (screw-box, sliding-lid, clamshell)
