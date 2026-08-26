# Bulgular

Bu proje kapsamında (Q# ile Grover Arama Algoritması, gerçek veri setleri üzerinde) Firecrawl ile yapılan araştırmaların özeti.

## 1. Veri Setleri

| Dosya | Kaynak | Boyut | Not |
|---|---|---|---|
| `data/countries_full.csv` | [datasets/country-list](https://github.com/datasets/country-list) | 250 satır | İlk basit demo |
| `data/grover_search_8.csv` | Yukarıdakinden türetildi | 8 satır (2³) | 3 qubit index demo |
| `data/titanic_full.csv` | [datasciencedojo/datasets](https://github.com/datasciencedojo/datasets) | 891 satır, 12 sütun | Gerçek, tanıdık veri |
| `data/grover_titanic_16.csv` | Titanik'ten türetildi | 16 satır (2⁴), 4 sütun | Tek hedefli (Index=15) temiz demo |
| `data/winequality_combined.csv` | UCI Wine Quality ([mirror](https://github.com/shrikant-temburwar/Wine-Quality-Dataset)) | 6.497 satır, 12 sütun | Titanik'ten büyük, 10.000 sınırı altında, tamamen sayısal |

## 2. Ortam Kurulumu

**QDK / `qsharp` Python paketi (PyPI, v1.31.0):**
- Gereksinim: Python **>=3.10**
- Resmi desteklenen: 3.10, 3.11, 3.12, 3.13
- Bu makinede sistem Python'u 3.14.7 — desteklenen aralığın üstünde, proje için ayrı venv (3.11/3.12) önerildi.

**Azure CLI kurulumu (Fedora):**
- Fedora, Microsoft'un resmi desteklenen dağıtım listesinde yok (Ubuntu/Debian, RHEL/CentOS, openSUSE/SLES var).
- Önerilen: RHEL 9 `dnf` reposu (`packages-microsoft-prod.rpm`) genelde sorunsuz çalışır; başarısız olursa dağıtımdan bağımsız `pip install --user azure-cli` yedek yöntem.
- `az login` oturumu `~/.azure`'da global olarak saklanır — hangi venv'den login olunursa olunsun her yerden okunur.

## 3. Azure Quantum Workspace

- Resource ID, Azure Portal'da **"Quantum Workspaces"** servisi aratılarak bulunur (resource group listesinde değil — `mrg-` önekli gruplar otomatik oluşturulan "managed resource group"lardır, asıl workspace kaynağı değildir).
- `rigetti.sim.qvm` hedefi: **ücretsiz ($0)**, sınırsız bulut simülatör — gerçek donanım (`rigetti.qpu.cepheus-1-108q`) ücretli/kotalı.
- Python'dan bağlantı: `azure-quantum` paketi, `Workspace(resource_id=...)` — ayrı bir API key gerekmez, `DefaultAzureCredential` zinciri (öncelik: env → managed identity → CLI → interaktif tarayıcı) kimlik doğrular.
- Kaynak: [how-to-submit-jobs](https://learn.microsoft.com/en-us/azure/quantum/how-to-submit-jobs), [provider-rigetti](https://learn.microsoft.com/en-us/azure/quantum/provider-rigetti)

## 4. Q# Proje Yapısı (`qsharp.json`)

- Zorunlu klasör yapısı: `qsharp.json` proje kökünde, tüm `.qs` dosyaları **`src/`** alt klasöründe.
- Minimum geçerli manifest: `{}` — `author`/`license`/`lints` isteğe bağlı.
- Notebook'tan erişim: `qsharp.init(project_root=...)` — yol, **kernel'in çalışma dizinine göre** çözülür (notebook'un bulunduğu klasöre göre değil, mutlaka doğrulanmalı).
- `qsharp.init()` her çağrıldığında context'i **sıfırdan** kurar — önceki çağrıdaki `project_root` hatırlanmaz, tüm parametreler (`project_root`, `target_profile` vb.) **tek çağrıda birlikte** verilmeli.
- Kaynak: [how-to-work-with-qsharp-projects](https://learn.microsoft.com/en-us/azure/quantum/how-to-work-with-qsharp-projects)

## 5. Literatür: Grover ile Gerçek Veri Seti Arama

**Bulgu — çoğu "database search" projesi aslında sahte:**
[yasaswiniii0822/Grover-s-algorithm-simulation](https://github.com/yasaswiniii0822/Grover-s-algorithm-simulation) gibi "Quantum Database Search" başlıklı projelerin çoğu, gerçek veri seti kullanmıyor — oracle, önceden bilinen sabit bir bit dizisini (`targetIndex`) işaretliyor. Cevap zaten biliniyor, Grover sadece gösterim amaçlı.

**Bulgu — bizimkiyle aynı yığın (Q#/Rigetti), ciddi girişim arşivlendi:**
[Quantum Grand Challenges — 15. Database Search](https://wernerrall147.github.io/quantum-grand-challenges/problems/15_database_search/) (qsharp 1.31.0, Rigetti QVM — bu projeyle birebir aynı):
> "Quadratic O(√N) Grover provably optimal but QRAM loading O(N) erases search advantage. Archived per Troyer framework."

Rakamlar: 4 mantıksal qubit için 61.1k fiziksel qubit; Grover'ın gerçek kazanç sağladığı eşik **N≈10⁶ (yapısal oracle) / N≈10¹² (naif oracle)**. Küçük ölçekli demolarda (16-64 satır) gerçek hız kazancı yok, beklenen.

**Bulgu — akademik çerçeve (üç bariyer):**
Liu, Y. (2026), [*The Grover Dilemma and Three Fundamental Barriers to Oracle-Based Quantum Search Algorithms*](https://www.scirp.org/pdf/jqis_1300507.pdf):
1. **Grover Dilemma:** hesaplama uzayı (2ⁿ), geçerli veri uzayını (N gerçek satır) aşarsa fazladan yapı gerekir.
2. **Setup Cost Dilemma:** oracle inşa/veri yükleme maliyeti klasik çözümün maliyetini geçerse avantaj sıfırlanır (QROM'un O(N) maliyeti tam olarak bu).
3. **Oracle Circularity:** bazı problemlerde oracle'ı kurmak, problemi çözmekle eşdeğerdir.

**Bulgu — alternatif desen: SAT/Boole ifadesi tabanlı oracle:**
[Qiskit Grover examples](https://qiskit-community.github.io/qiskit-algorithms/tutorials/07_grover_examples.html) ve [Q# Katas — SolveSATWithGrover](https://github.com/microsoft/QuantumKatas/blob/main/SolveSATWithGrover/Tasks.qs) (`Oracle_SAT`, `Oracle_Exactly1_3SAT`): qubit'ler doğrudan değişkenleri temsil eder, oracle maliyeti **formül karmaşıklığına** bağlıdır, veri seti boyutuna (N) değil — QROM'a göre gerçekten daha ucuz.

*Ancak:* bu desen problemin tanımını değiştirir — "veri setimdeki gerçek satırı bul" yerine "değişkenlerin olası TÜM kombinasyonları içinde formülü sağlayanı bul" sorusuna cevap verir. Bulunan kombinasyonun veri setinde **gerçekten var olan bir satıra karşılık geldiği** garanti değildir; bunu garanti etmek için satır-üyelik kısıtı eklemek yeniden O(N) maliyetine döner (Grover Dilemma).

## 6. Grover Dilemma'nın Netleştirilmesi (Type A / Type B)

Liu makalesinin Bölüm 3'ü tekrar okunarak doğrulandı — Grover Dilemma "her aramada yeniden derleme" gibi zamansal bir maliyet **değil**, tek seferlik **yapısal bir uyumsuzluk**:

- **S** = hesaplama uzayı (n qubit'in temsil edebildiği 2ⁿ durum), **D** = geçerli veri uzayı (gerçekten var olan satırlar).
- `|S| > |D|` ise problem **Type A**'dır ve dilemma vardır: süperpozisyondaki "hayalet" index'ler (gerçek satıra karşılık gelmeyen durumlar) yanlış pozitif riski taşır ve genlik israf eder.
- `|S| = |D|` ise **Type B**'dir, dilemma yoktur.

**Projedeki karşılığı:** `grover_titanic_16.csv` (16 = 2⁴ → Type B, sorunsuz) vs `winequality_combined.csv` (6.497 satır, 13 qubit → 8.192 durum → **1.695 hayalet index**, Type A).

**Çözüm ve sınırı:** Veri setini 4.096 = 2¹² satıra kırpmak Type A→B dönüşümü sağlar — ama bu **doğruluk** düzeltmesidir, hız kazandırmaz: Setup Cost (QROM'un O(N) inşası) aynen kalır. Toplam maliyet O(N) + O(√N) ≈ O(N) — kırpma, √N kazancının "kolpa"lığını değiştirmez; o ayrı bir bariyerdir.

## 7. SAT-Oracle'ın Döndürdüğü Şey ve O(N)'in Kaçınılmazlığı

Aaronson'ın ["Read the Fine Print"](https://www.scottaaronson.com/papers/qml.pdf) makalesi (Nature Physics 2015) ve [PennyLane QROM dokümanı](https://pennylane.ai/demos/tutorial_intro_qrom) taranarak doğrulandı:

- **Değer-qubit (SAT) yaklaşımında ölçüm bir "değer ataması" döndürür** (örn. `quality=9, type=red`) — **indis döndürmez**, çünkü satır kimliği devrenin hiçbir yerinde kodlanmamıştır; ölçüm, devreye kodlanmamış bilgiyi üretemez. Dar sorguda (örn. `quality==7 AND type==red`) dönen atama sorgunun kendisidir — arama fiilen yok olur.
- **Üyelik kısıtı neden O(N):** "Bu değer 4.096 satırımdan biri mi" kısıtının genel yolu satır başına bir eşitlik klozu OR'lamaktır; PennyLane dokümanına göre QROM zaten `Select` operatörünün özel halidir (her `Uᵢ` = X kapıları çarpımı) — yani "kloz listesi" ile "QROM" **aynı devrenin iki adıdır**.
- **Bilgi-kuramsal sebep:** Devre, algoritmanın tek hafızasıdır; keyfi (yapısız) bir N-satırlık alt kümenin kısa tanımı yoktur (~N×W bit gerekir) ve bu tanım kapı listesinde taşınmak zorundadır. Yeni literatür (arXiv 2607.28260) maliyet indirimlerini hep **seyreklik/yapı varsayımına** bağlar.
- **Aaronson'ın 1 numaralı uyarısı** birebir bu: veri, kuantum belleğe *hız kazancını koruyacak kadar verimli* yüklenebilmelidir — keyfi klasik veri için yüklenemez.

**Özlü formül:** Bilgi ya sorguda ya devrede olmak zorunda; ikisinde de yoksa ölçümde de yok. Sorguya koyarsan cevabı zaten biliyorsun, devreye koyarsan O(N) ödüyorsun.

## 8. Sıralama Algoritmaları Araştırması

Ayrı rapor: [siralama_algoritmalari.md](siralama_algoritmalari.md) — en verimli 10 sıralama algoritması, N=4096 üzerinden somut işlem sayıları ve kazanç katlarıyla (kaynaklar: Sort & Visualize, GeeksforGeeks). Özet: dar tam sayı anahtarlarda Counting Sort (~4.100 işlem) > Radix > Bucket; genel amaçlı şampiyon Pdqsort/Introsort (~49.200 karşılaştırma); O(N²) tabana göre ~341-4.000× kazanç.

## 9. Wine Veri Setinin Counting Sort / Quantize Analizi

Tüm sütunlar gerçek veri üzerinden tarandı (min, max, ondalık hassasiyet, ölçekli k):

- **Doğrudan uygun (2):** `quality` (k=7), `type` (2 kategori).
- **Ölçekleyince uygun (9):** `fixed/volatile acidity`, `citric acid`, `residual sugar`, `chlorides`, `free/total sulfur dioxide`, `pH`, `sulphates` — 10^d ölçeğiyle k=130-6.521 aralığında, k ≤ N.
- **Sorunlu (2):**
  - `alcohol`: dosyada 14 ondalıklı float artıkları var (`11.066666666666666` — devirli sayı kayıt hatası); ham k≈10¹⁴. **2 ondalığa yuvarlama kayıpsız çözüm:** k=691, farklı değer 111/112 korunuyor.
  - `density`: bilgisi 3.-5. ondalıkta yaşıyor; 2 ondalıkta sütun imha olur (998→4 farklı değer). **Doğru nokta 4 ondalık:** k=520, 156 farklı değer.

**Pandas çözümü** (orijinal sütunlar korunur, quantize edilmiş tam sayı sütunları eklenir):
```python
df["alcohol_q"] = (df["alcohol"].round(2) * 100).round().astype(int)    # k≈691
df["density_q"] = (df["density"].round(4) * 10_000).round().astype(int) # k≈520
```
İkinci `.round()` şart — float çarpımı `7.399999` üretebilir, doğrudan `astype(int)` yanlış kırpar.

**Çifte kullanım:** Bu `_q` sütunları hem counting sort'un anahtarı hem QROM qubit kodlamasının girdisidir — tek ön işleme, iki kullanım.

## 10. Sonuç

Projede benimsenen tasarım — QROM ile veri setini devreye gömme + sorgu değerlerini runtime parametre olarak gönderme — literatürdeki "doğru ama bilinen şekilde pahalı" yaklaşımın kendisi. Küçük ölçekli (16-64 satır) demo için tamamen uygun; gerçek hız kazancı beklenmiyor, amaç mekanizmayı doğru göstermek. SAT-oracle deseni, sorgu-karşılaştırma adımının maliyetini düşürebilir ama QROM'un (veri setine ait olma kontrolü) yerini almaz — ikisi tamamlayıcı, birbirinin alternatifi değil. Veri seti 4.096 satıra kırpılarak Type A→B dönüşümü yapılmalı (doğruluk için) ve `alcohol`/`density` sütunları quantize edilmeli (hem sıralama hem qubit kodlaması için).
