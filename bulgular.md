# Bulgular

Q# ile Grover Arama Algoritmasını gerçek bir veri seti üzerinde uçtan uca çalıştırmak için yaptığım araştırmaların ve deneylerin özeti. Microsoft FY26 Yaz Stajı dönemi kapsamında uyguladım, araştırdım ve belgeledim.

## 1. Veri Seti

Projede `data/winequality_combined.csv` dosyasını kullandım: UCI Wine Quality veri setinin kırmızı ve beyaz şarap dosyalarını birleştirerek oluşturdum ([kaynak](https://github.com/shrikant-temburwar/Wine-Quality-Dataset)). 6.497 gözlem, 12 fizikokimyasal değişken + tür (red/white) sütunu; tamamen sayısal ve eksiksiz.

## 2. Ortam Kurulumu

**QDK / `qsharp` Python paketi (PyPI, v1.31.0):**

- Gereksinim: Python >= 3.10; resmi desteklenen sürümler 3.10, 3.11, 3.12, 3.13.
- Sistem Python'um desteklenen aralığın dışında kaldığı için projeye ayrı bir sanal ortam kurdum.

**Azure CLI:**

- `az login` oturumu `~/.azure` dizininde global saklanıyor; hangi sanal ortamdan giriş yapılırsa yapılsın her yerden okunuyor. `azure-quantum` paketinin `DefaultAzureCredential` zinciri bu oturumu otomatik buluyor.

## 3. Azure Quantum Workspace

- Resource ID'yi Azure Portal'da "Quantum Workspaces" servisini aratarak buldum; resource group listesinde görünen `mrg-` önekli kayıtlar otomatik oluşturulan yönetilen gruplardır, asıl workspace kaynağı değildir.
- `rigetti.sim.qvm` hedefi ücretsizdir; gerçek donanım (`rigetti.qpu.cepheus-1-108q`) ücretli ve kotalıdır.
- Python bağlantısı için ayrı bir API anahtarı gerekmez: `Workspace(resource_id=...)` yeterli, kimlik doğrulamayı `DefaultAzureCredential` zinciri yapar.
- Kaynak: [how-to-submit-jobs](https://learn.microsoft.com/en-us/azure/quantum/how-to-submit-jobs), [provider-rigetti](https://learn.microsoft.com/en-us/azure/quantum/provider-rigetti)

## 4. Q# Proje Yapısı (`qsharp.json`)

- Zorunlu klasör yapısı: `qsharp.json` proje kökünde, tüm `.qs` dosyaları `src/` alt klasöründe.
- Minimum geçerli manifest: `{}`.
- Notebook'tan erişim: `qsharp.init(project_root=...)`; yol, kernel'in çalışma dizinine göre çözülür, notebook'un bulunduğu klasöre göre değil.
- `qsharp.init()` her çağrıldığında context'i sıfırdan kurar; önceki çağrıdaki `project_root` hatırlanmaz. Tüm parametreleri (`project_root`, `target_profile` vb.) tek çağrıda birlikte vermek gerekir.
- Kaynak: [how-to-work-with-qsharp-projects](https://learn.microsoft.com/en-us/azure/quantum/how-to-work-with-qsharp-projects)

## 5. Literatür: Grover ile Gerçek Veri Seti Arama

**Çoğu "database search" projesi gerçek arama yapmıyor:** [Örnek bir repo](https://github.com/yasaswiniii0822/Grover-s-algorithm-simulation) gibi "Quantum Database Search" başlıklı projelerin çoğunda oracle, önceden bilinen sabit bir bit dizisini (`targetIndex`) işaretliyor. Cevap zaten bilindiği için Grover yalnızca gösterim amaçlı kalıyor.

**Benim kullandığım yığının aynısıyla (Q# 1.31.0 / Rigetti QVM) yapılmış ciddi bir girişim arşivlenmiş:** [Quantum Grand Challenges, 15. Database Search](https://wernerrall147.github.io/quantum-grand-challenges/problems/15_database_search/):

> "Quadratic O(sqrt N) Grover provably optimal but QRAM loading O(N) erases search advantage. Archived per Troyer framework."

Rakamlar: 4 mantıksal kübit için 61.1k fiziksel kübit; Grover'ın gerçek kazanç sağladığı eşik N=10^6 (yapısal oracle) / N=10^12 (naif oracle). Küçük ölçekli demolarda gerçek hız kazancı beklenmez.

**Akademik çerçeve (üç bariyer):** Liu, Y. (2026), [The Grover Dilemma and Three Fundamental Barriers to Oracle-Based Quantum Search Algorithms](https://www.scirp.org/pdf/jqis_1300507.pdf):

1. **Grover Dilemma:** Hesaplama uzayı (2^n) geçerli veri uzayını (N gerçek satır) aşarsa fazladan yapı gerekir.
2. **Setup Cost Dilemma:** Oracle inşa / veri yükleme maliyeti klasik çözümün maliyetini geçerse avantaj sıfırlanır (QROM'un O(N) maliyeti tam olarak bu).
3. **Oracle Circularity:** Bazı problemlerde oracle'ı kurmak, problemi çözmekle eşdeğerdir.

**Alternatif desen, SAT tabanlı oracle:** [Qiskit Grover examples](https://qiskit-community.github.io/qiskit-algorithms/tutorials/07_grover_examples.html) ve [Q# Katas SolveSATWithGrover](https://github.com/microsoft/QuantumKatas/blob/main/SolveSATWithGrover/Tasks.qs) desenlerinde kübitler doğrudan değişkenleri temsil eder; oracle maliyeti formül karmaşıklığına bağlıdır, veri seti boyutuna değil. Ancak bu desen problemin tanımını değiştirir: "veri setimdeki gerçek satırı bul" yerine "olası tüm değer kombinasyonları içinde formülü sağlayanı bul" sorusuna cevap verir. Bulunan kombinasyonun veri setinde gerçekten var olduğu garanti değildir; bunu garanti eden satır-üyelik kısıtı eklemek maliyeti yeniden O(N) yapar.

## 6. Grover Dilemma'nın Netleştirilmesi (Type A / Type B)

Liu makalesinin 3. bölümünü okuyarak netleştirdim. Grover Dilemma zamansal bir maliyet değil, tek seferlik yapısal bir uyumsuzluktur:

- S = hesaplama uzayı (n kübitin temsil edebildiği 2^n durum), D = geçerli veri uzayı (gerçekten var olan satırlar).
- |S| > |D| ise problem Type A'dır: süperpozisyondaki "hayalet" indeksler (gerçek satıra karşılık gelmeyen durumlar) yanlış pozitif riski taşır ve genlik israf eder.
- |S| = |D| ise Type B'dir, dilemma yoktur.

**Projedeki karşılığı:** 6.497 satırlık wine seti 13 kübit gerektirir (8.192 durum), yani 1.695 hayalet indeks oluşur (Type A). Veri setini 2^n satıra (4.096, deneylerde 64 ve 8) kırparak Type B'ye dönüştürdüm. Bu bir doğruluk düzeltmesidir, hız kazandırmaz: Setup Cost (QROM'un O(N) inşası) aynen kalır ve toplam maliyeti O(N) yapar; sqrt(N) sorgu avantajını pratikte geçersiz kılan da budur.

## 7. SAT-Oracle'ın Döndürdüğü Şey ve O(N)'in Kaçınılmazlığı

Aaronson'ın ["Read the Fine Print"](https://www.scottaaronson.com/papers/qml.pdf) makalesini (Nature Physics 2015) ve [PennyLane QROM dokümanını](https://pennylane.ai/demos/tutorial_intro_qrom) tarayarak doğruladım:

- Değer-kübit (SAT) yaklaşımında ölçüm bir değer ataması döndürür (örn. `quality=9, type=red`), indis döndürmez; satır kimliği devrenin hiçbir yerinde kodlanmadığı için ölçüm onu üretemez. Dar sorguda dönen atama sorgunun kendisidir, arama fiilen ortadan kalkar.
- Üyelik kısıtı neden O(N): "Bu değer N satırımdan biri mi" kontrolünün genel yolu satır başına bir eşitlik klozu OR'lamaktır. PennyLane dokümanına göre QROM zaten `Select` operatörünün özel halidir; yani "kloz listesi" ile "QROM" aynı devrenin iki adıdır.
- Bilgi-kuramsal sebep: Devre, algoritmanın tek hafızasıdır. Keyfi bir N-satırlık alt kümenin kısa tanımı yoktur (yaklaşık N x W bit gerekir) ve bu tanım kapı listesinde taşınmak zorundadır. Güncel literatür (arXiv 2607.28260) maliyet indirimlerini hep seyreklik/yapı varsayımına bağlar.

Özet: Bilgi ya sorguda ya devrede olmak zorunda; ikisinde de yoksa ölçümde de yok. Sorguya koyarsam cevabı zaten biliyorum, devreye koyarsam O(N) ödüyorum.

## 8. Veri Setinin Quantize Analizi

Kuantum karşılaştırıcılar tam sayı bitleriyle çalıştığı için tüm sütunları gerçek veri üzerinden taradım (min, max, ondalık hassasiyet):

- Doğrudan uygun: `quality` (tam sayı), `type` (2 kategori).
- Ölçekleyince uygun (9 sütun): 10^d çarpanıyla tam sayıya çevrilebiliyor (d = sütunun ondalık hanesi).
- Sorunlu iki sütun:
  - `alcohol`: dosyada 14 ondalıklı float artıkları var (`11.066666666666666` gibi devirli sayı kayıtları). 2 ondalığa yuvarlama kayıpsız çözüm oldu (112 farklı değerin 111'i korunuyor).
  - `density`: bilgisi 3.-5. ondalıkta yaşıyor; 2 ondalıkta sütun anlamını yitiriyor (998 farklı değer 4'e düşüyor). Doğru hassasiyet 4 ondalık (156 farklı değer korunuyor).

Pandas tarafında ölçek katsayılarını quantize işleminin yapıldığı satırda `scale` sözlüğüne kaydettim; sorgu değerlerini insan birimleriyle yazıp (`7.3` gibi) çeviriyi `q()` yardımcı fonksiyonuna bıraktım. Fonksiyon içindeki `assert v.bit_length() <= weight[col]` kontrolü, sütuna sığmayan sorgu değerlerini Q#'a gitmeden Python tarafında okunur bir mesajla yakalıyor.

## 9. Bilinmeyen Çözüm Sayısı (M) ve BBHT Algoritması

Grover iterasyon formülü `floor(pi/4 * sqrt(N/M))` içindeki M (sorguyu sağlayan gerçek satır sayısı), çalışma zamanında gelen sorguya bağlı olduğu için derleme zamanında bilinemez. Önce M=1 (tek eşleşme) varsaydım; sonra M'yi `expectedMatches` adıyla operasyon parametresi yaptım: kullanıcı kaç eşleşme beklediğini tahmin olarak veriyor, cevabı pandas ile sayıp göndermiyorum (o zaman aramanın anlamı kalmazdı). Yanlış tahmin sonucu bozmaz, sadece olasılığı düşürür.

**Yuvarlama bulgusu:** Formülü önce `Round` ile yazmıştım; M=2, N=8 durumunda pi/4 * sqrt(4) = 1,57 değeri 2 tura yuvarlanıyor ve genlik tepe noktasını aşıyordu (teorik basari 2 turda %25, 1 turda %100). `Floor` ile 1 tur atılıyor ve ölçüm 50/50 iki eşleşmeye yığılıyor. Literatürdeki formülün tabanı da `Floor`.

**Kaynak:** Boyer, Brassard, Hoyer, Tapp, ["Tight Bounds on Quantum Searching"](https://arxiv.org/abs/quant-ph/9605034) (1996), Bölüm 4.

**Yanlış M tahmininin bedeli (makaledeki örnek):** 2^20 olasılık içinde tek çözüm varsa 804 iterasyon neredeyse kesin buluyor; gerçekte 4 çözüm varken aynı 804 iterasyon bulma olasılığını milyonda birin altına düşürüyor. Fazla iterasyon genliği tepe noktasından geri döndürüyor.

**BBHT algoritması (M bilinmeden, katlanarak artan deneme):**

1. m = 1, lambda = 6/5 (1 ile 4/3 arası herhangi bir değer çalışır).
2. 0 ile m-1 arasından rastgele bir j seç.
3. Eşit süperpozisyondan itibaren j kez oracle + diffuser uygula.
4. Ölç; sonuç sorguyu sağlıyorsa bitti.
5. Sağlamıyorsa m = min(lambda*m, sqrt(N)) yap, 2. adıma dön.

Beklenen toplam iterasyon M bilinmeden de O(sqrt(N/M)) mertebesinde kalıyor. Ancak BBHT her denemeden sonra klasik bir karar gerektirdiği için tek seferlik `target.submit(...)` iş gönderim modeliyle uyuşmuyor; her deneme ayrı bir Azure Quantum işi olurdu. Bu nedenle M=1 sabit varsayımıyla ilerledim.

## 10. QDK Derleyici Hatası: Partial Evaluation'da BigInt Desteği Yok

**Belirti:** `qsharp.compile(op, queries, dataset)` çağrısı `Qdk.Qsc.PartialEval.Unexpected: unsupported LHS value: 7` hatası verdi.

**Kök neden (derleyici kaynak koduna inerek doğruladım, qsharp/qdk 1.31.0 ve `main`):**

- Partial evaluator ([qsc_partial_eval/src/lib.rs](https://github.com/microsoft/qdk/blob/main/source/compiler/qsc_partial_eval/src/lib.rs)) ikili işlemlerde LHS tipi olarak Array/Result/Bool/Int/Double/Var/String/Pauli destekliyor; BigInt dalı yok.
- `Std.Arithmetic.ApplyIf*L` ailesi içeride BigInt aritmetiği yapıyor (`ApplyIfLessL` içinde `c + 1L`, `ApplyIfEqualL` içinde `BitSizeL(c)`). `IntAsBigInt(value)` sabiti kütüphane gövdesinde ikili işleme girdiği anda derleme patlıyor.
- `main` branch'inde de düzeltilmemiş; sürüm yükseltmek çare değil.

**Hedef değiştirmek de çare değil:** Hata yerelde, Azure'a hiçbir şey gitmeden önce oluşuyor; QIR'de BigInt hiçbir profilde yok.

**Bulduğum çözüm, BigInt'e hiç bulaşmamak:** `ApplyControlledOnInt` tamamen Int tabanlı (kaynaktan doğruladım):

- `==` / `!=` için doğrudan `ApplyControlledOnInt(value, X, dilim, aux)`.
- Eşitsizlikler için koşulu sağlayan klasik değer aralığı üzerinde döngü: `x > value` için `value+1 .. 2^weight - 1` aralığındaki her v'ye `ApplyControlledOnInt(v, X, dilim, aux)` (diğer operatörler için ilgili aralıklar). Her taban durumunda en fazla bir değer tetiklendiği için mantık doğru. Maliyet sorgu başına O(2^weight) çok-kontrollü kapı; QROM zaten baskın olduğundan kabul edilebilir.

## 11. Bulut Denemeleri: Ölçek Duvarları, QAT ve Servis Hataları

**Ölçek duvarı 1, yerel derleme:** 4.096 satır x 119 bit konfigürasyonu `qsharp.compile` sırasında makineyi dondurdu (yaklaşık 24,5M çok-kontrollü kapı). Asıl kısıtın kübit bütçesi olduğunu gördüm: toplam kübit = n + W + 1 (marker) + k (sorgu) = 12+119+1+2 = 134 kübit; hiçbir simülatöre veya QPU'ya sığmaz.

**Çözümüm, QROM'a sadece sorgulanan sütunları koymak:** Oracle yalnızca sorgunun dokunduğu sütunları okur; kalan sütunları ölçüm sonrası pandas `iloc` ile klasik olarak getiriyorum. Sütun listesini 2 sütuna indirdim (fixed acidity 7 bit + quality 3 bit = W=10): 64 satırda 24 kübit, 38.665 ccx.

**Rigetti zinciri (ücretsiz `rigetti.sim.qvm` hedefinde):**

1. 64 satır: `QATTransformationFailed` (hata dökümünde gerçek mesaj yok, sadece yapılandırma).
2. Mini CCNOT testi: başarılı, gönderimden sonuca 27 saniye. Kapı seti sorun değil (QAT `ccx`'i kendisi ayrıştırıyor); engel ölçek.
3. 8 satır (21 kübit, 601 ccx): QAT geçti (gönderimden hataya ~38 saniye), ancak QVM `lparallel: MAKE-KERNEL` Lisp hatası verdi: Azure'daki barındırılan QVM örneğinin worker thread havuzu yapılandırılmamış. Saatler arayla iki kez denedim, aynı deterministik hata; servis tarafı bir bozukluk, istemciden çözülemiyor. Rigetti QVM gürültüsüz bir simülatör olduğu için çalışsaydı yerel sonucumla aynı tepeyi verecekti.

**Kübit sınırları (kaynaklar: [provider-quantinuum](https://learn.microsoft.com/en-us/azure/quantum/provider-quantinuum), [provider-rigetti](https://learn.microsoft.com/en-us/azure/quantum/provider-rigetti), [QVM GitHub](https://github.com/quil-lang/qvm)):**

| Hedef | Kübit | Not |
|---|---|---|
| `quantinuum.sim.h2-1sc/h2-2sc` | 56 | Ücretsiz syntax checker, sonuç hep 0 |
| `quantinuum.sim.h2-1e/h2-2e` | 56/32 | 56 sadece stabilizer; T kapılı devrem için fiilen 32 |
| `quantinuum.qpu.h2-1/h2-2` | 56 | Ücretli |
| `rigetti.sim.qvm` | ilan edilmemiş | Bellek sınırlı statevector; yaklaşık 29-30 pratik sınır |
| `rigetti.qpu.cepheus-1-108q` | 108 | Ücretli; bu derinlikte devre gürültüde erir |

24 kübitlik devrem kapasite olarak her hedefe sığıyor; Rigetti başarısızlığı kapasite değil, servis hatası.

## 12. Uçtan Uca Doğrulama ve Quantinuum Testleri

**`qsharp.run` imza notu:** `run(entry_expr, shots, *args)`; `shots` ikinci pozisyonel parametre, callable argümanlarından önce gelir (`compile(entry_expr, *args)` imzasından farklı).

**Yerel doğrulama (başarılı):** 64 satır x 2 sütun (W=10, 24 kübit, 6 Grover iterasyonu), sorgu `fixed acidity == 7.3 AND quality >= 7`, yerel simülatör, 100 shot, toplam süre 1 dakika 20 saniye:

```text
[(7, 98), (33, 1), (54, 1)]
```

%98 olasılıkla indeks 7. Aynı sorgunun pandas kontrolü de `[7]` döndürdü: kuantum ve klasik cevap örtüşüyor. Rastgele seçim tabanı %1,6 olurdu; 6 iterasyonluk amplifikasyonun teorik beklentisi (~%99) ile ölçüm uyumlu. QROM + karşılaştırıcı + faz kickback + diffuser + iterasyon hesabı zincirini uçtan uca doğruladım.

**Tespit ettiğim ve kapattığım gizli tuzak, sütun bit sırası (endianness):** `row_to_bits` sütun değerlerini MSB-first yazıyordu; `ApplyControlledOnInt` ise dilimi little-endian okur. Yani karşılaştırıcı aslında sorgu değerinin bit-tersini arıyordu. İlk deneylerde sonuç etkilenmedi çünkü 73 (`1001001`) ve 7 (`111`) ikili palindrom. Hatayı gerçek bir test yakaladı: OR sorgusuna 112 (`1110000`, palindrom değil) değerini verdiğimde devre onu little-endian okuyup 7 sandı ve satırı hiç işaretlemedi. Düzeltme: `row_to_bits` içinde `reversed(binary_str)`; sonrasında 112'li regresyon testi doğru satırı buldu.

**Quantinuum testleri:**

- `h2-1sc` syntax checker (ücretsiz): 8 satırlık programı kabul etti (Succeeded; çıktı tasarım gereği tümü 0). İlan edilen kuyruk 2 saniye olmasına rağmen iş 10 dakikadan uzun kuyrukta bekledi. 64 satırlık program ise saniyeler içinde `InternalError` ile reddedildi; mini CCNOT testi geçtiği için bunun servis arızası değil, program hacmine bağlı bir red olduğunu ayrıştırdım.
- **Kota dersi:** `h2-1e` emülatörüne 100 shot'lık iş 1076 eHQC talep etti; tek seferlik kota 1000 olduğu için `NotEnoughQuota` ile çalışmadan reddedildi. Maliyet formülü yaklaşık `5 + shots x (1q + 10x2q + 5xolcum)/5000`; devremde shot başına ~10,7 eHQC.
- `shots=10` (~112 eHQC) ile çalıştı; kuyruk + çalıştırma toplamı yaklaşık 1 saat sürdü (hedefin ilan ettiği ortalama kuyruk 53-72 dakika aralığındaydı). **Sonuç: düz histogram** `{001:0.1, 011:0.2, 100:0.2, 111:0.2, 000:0.2, 110:0.1}`; beklenen `[1,1,1]` (indeks 7) tepesi yok.
- **Sebep (beklenen NISQ gerçeği):** `h2-1e` gerçekçi H2 gürültü modeli kullanıyor. 601 ccx yaklaşık 5.000 iki-kübit kapıya ayrışıyor; ~%99,8 kapı sadakatiyle başarı olasılığı 0,998^5000 = ~5x10^-5, sinyal tamamen gürültüde eriyor. Bölüm 5'teki Grand Challenges gürültü tablosunun deneysel doğrulaması: QROM tabanlı Grover bu derinlikte NISQ donanımında pratik değil ve bunu kendi deneyimle doğrulamış oldum.

## 13. Mantıksal Operatörler: AND/OR Desteği

Sorgu listesine birden çok koşul koyduğumda bunların VE mi VEYA mı davrandığını başta hiç düşünmemiştim; sorgulayınca yapının örtük olarak VE davrandığını fark ettim (marker, çok kontrollü X nedeniyle ancak tüm aux kübitleri 1 iken çevriliyor). Bunun üzerine formatı, mantıksal operatörü açıkça taşıyacak şekilde genişlettim: `(mantıksal operatör, [karşılaştırma listesi])`, Q# tipi `(Int, (Int, Int, Int, Int)[])`. 0 = AND (tüm koşullar sağlanmalı), 1 = OR (en az biri sağlanmalı). Python tuple Q# tuple'a, Python listesi Q# dizisine eşlendiği için dış yapının tuple olması zorunlu.

- **AND:** aux kübitleri üzerinde çok kontrollü X (`Controlled X(auxs, marker)`); yalnız tüm aux'lar 1 iken marker çevrilir.
- **OR (De Morgan):** "en az biri 1" = "hepsi 0 DEĞİL". Aux'lar X ile ters çevrilip çok kontrollü X uygulanır (NOR), sondaki koşulsuz X NOR'u OR'a tamamlar. Koşulsuz X'in |-> üzerindeki etkisi genel faz olduğu için sonucu bozmaz.
- **XOR tuzağı:** OR'u iki karşılaştırmayı ayni aux'a yazarak yapmak yanlıştır; iki koşul ayni satırda ayni anda doğruysa aux iki kez çevrilip 0'a döner (OR değil XOR). Doğru yol karşılaştırma başına ayrı aux + De Morgan.
- **Sınır:** Yapı tek seviyeli; "a AND (b OR c)" gibi karışık ifade için gruplar listesi (CNF: grup içi OR, gruplar arası AND) gerekir. Q#'ta özyinelemeli tip olmadığı için keyfi derinlik zaten mümkün değil.

**Doğrulama (yerel, 8 satır, 100 shot):**

- AND (`fixed acidity == 7.3 VE quality >= 7`): pandas `[7]`, Grover %95-98 indeks 7.
- OR, M=1 (`fixed acidity == 11.2 VEYA quality == 4`): pandas `[3]`, Grover %91 indeks 3.
- OR, M=2 (`fixed acidity == 11.2 VEYA quality >= 7`): pandas `[3, 7]`; `expectedMatches=2` ile Grover tam 50/50 `[3, 7]`. Ayni sorgu `expectedMatches=1` ile düz dağılım verdi: souffle probleminin (Bölüm 9) kendi devremdeki deneysel gözlemi. OR birden çok eşleşme üretmeye yatkın olduğu için M tahmini OR ile birlikte daha da önemli hale geldi.

Bu çalışma iki hatayı da yakaladı: 112 değeri endianness tuzağını görünür kıldı (Bölüm 12) ve M=2 senaryosu iterasyon formülündeki Round/Floor farkını ortaya çıkardı (Bölüm 9).

## 14. Sonuç: Neyi Çözdüm

Bu projede şu problemi çözdüm: **kullanıcının çalışma zamanında verdiği çok koşullu bir sorguyu (sütun, operatör, değer üçlüleri; ==, !=, >, <, >=, <= karşılaştırmaları ve AND/OR mantıksal operatörleri destekli) kuantum devresi içinde değerlendirip, eşleşen gözlemin indeksini Grover araması ile bulan ve satırın tamamını pandas ile geri getiren, gerçek bir veri seti üzerinde çalışan uçtan uca bir sistem kurdum.** Cevabı önceden devreye gömen "database search" demolarının aksine, arama gerçekten devre içinde yapılıyor: veri QROM ile yükleniyor, koşullar kübitler üzerinde karşılaştırılıyor, indeks ölçümle bulunuyor.

Bu süreçte çözdüğüm somut alt problemler:

1. Gerçek veri setini (winequality_combined.csv) kübitlere kodlanabilir hale getirdim: 2^n kırpma (Type A/B dönüşümü), sütun quantize analizi, ölçek sözlüğü ve sınır kontrollü sorgu çevirisi.
2. QDK derleyicisindeki BigInt hatasını kaynak koda inerek teşhis ettim ve `ApplyControlledOnInt` tabanlı, BigInt içermeyen bir karşılaştırıcı tasarımıyla aştım.
3. 134 kübitlik tasarımı, "QROM'a sadece sorgulanan sütunlar" kararıyla 24 kübite indirip derlenebilir ve çalıştırılabilir hale getirdim.
4. Yerel simülatörde %98 doğrulukla, klasik kontrolle örtüşen uçtan uca sonucu ürettim.
5. Bulut tarafında Rigetti QVM'in servis hatasını, Quantinuum'un hacim bazlı reddini, eHQC kota modelini ve gürültü modelli emülatörde sinyalin erimesini deneylerle belgeledim.
6. Sorgu formatına AND/OR mantıksal operatörlerini ekledim (OR için De Morgan yapısı); bu genişletme sırasında endianness tuzağını `reversed()` yamasıyla, iterasyon formülündeki Round hatasını `Floor` düzeltmesiyle kapattım ve M'yi kullanıcı tahmini olarak parametreye çevirdim.

Genel çıkarım: Mekanizma doğru ve ideal simülatörde kanıtlandı; ancak QROM'un O(N) yükleme maliyeti ve NISQ gürültüsü, bu yaklaşımın bugünkü donanımda pratik hız kazancı sunmasını engelliyor. Bu sınır literatürde öngörülüyordu; ben de kendi devremde deneysel olarak doğruladım. Daha önce açık bıraktığım endianness düzeltmesi de uygulandı ve palindrom olmayan değerle (112) regresyon testinden geçti; bekleyen düzeltme kalmadı.

---

# Findings

This is a summary of my research and experiments. I ran Grover's Search Algorithm on a real dataset with Q#, from start to finish. I did this work during the Microsoft FY26 Summer Internship period.

## 1. Dataset

I used `data/winequality_combined.csv`. I made this file by joining the red wine and white wine files of the UCI Wine Quality dataset ([source](https://github.com/shrikant-temburwar/Wine-Quality-Dataset)). It has 6,497 rows and 12 numeric columns, plus a type column (red/white). There are no missing values.

## 2. Environment Setup

**QDK / `qsharp` Python package (PyPI, v1.31.0):**

- It needs Python 3.10 or newer. The official versions are 3.10, 3.11, 3.12 and 3.13.
- My system Python was too new, so I created a separate virtual environment for the project.

**Azure CLI:**

- The `az login` session is saved in the `~/.azure` folder. Every virtual environment can read it. The `azure-quantum` package finds this session by itself with `DefaultAzureCredential`.

## 3. Azure Quantum Workspace

- I found the Resource ID in the Azure Portal by searching for "Quantum Workspaces". The `mrg-` groups in the resource group list are automatic system groups. They are not the real workspace.
- The `rigetti.sim.qvm` target is free. Real hardware (`rigetti.qpu.cepheus-1-108q`) costs money and has a quota.
- You do not need an API key in Python. `Workspace(resource_id=...)` is enough. `DefaultAzureCredential` does the login.
- Sources: [how-to-submit-jobs](https://learn.microsoft.com/en-us/azure/quantum/how-to-submit-jobs), [provider-rigetti](https://learn.microsoft.com/en-us/azure/quantum/provider-rigetti)

## 4. Q# Project Structure (`qsharp.json`)

- The rule is: `qsharp.json` goes in the project root, and all `.qs` files go in the `src/` folder.
- The smallest valid manifest is `{}`.
- In a notebook you call `qsharp.init(project_root=...)`. The path starts from the kernel's working folder, not from the notebook's folder.
- Every `qsharp.init()` call builds a new context from zero. It forgets the old `project_root`. So you must give all parameters (`project_root`, `target_profile` etc.) in one call.
- Source: [how-to-work-with-qsharp-projects](https://learn.microsoft.com/en-us/azure/quantum/how-to-work-with-qsharp-projects)

## 5. Literature: Grover Search on Real Datasets

**Most "database search" projects do not really search.** In most repos with this title (like [this example](https://github.com/yasaswiniii0822/Grover-s-algorithm-simulation)), the oracle marks a bit string that is already known (`targetIndex`). The answer is known before the search starts. So Grover is only a show there.

**One serious project used the same tools as me (Q# 1.31.0 / Rigetti QVM). It was stopped and archived:** [Quantum Grand Challenges, 15. Database Search](https://wernerrall147.github.io/quantum-grand-challenges/problems/15_database_search/):

> "Quadratic O(sqrt N) Grover provably optimal but QRAM loading O(N) erases search advantage. Archived per Troyer framework."

Their numbers: 4 logical qubits need 61.1k physical qubits. Grover gives a real gain only after N=10^6 (structured oracle) or N=10^12 (naive oracle). So a small demo cannot show a real speedup. This is normal.

**Academic framework (three barriers):** Liu, Y. (2026), [The Grover Dilemma and Three Fundamental Barriers to Oracle-Based Quantum Search Algorithms](https://www.scirp.org/pdf/jqis_1300507.pdf):

1. **Grover Dilemma:** The circuit space (2^n) can be bigger than the real data space (N rows). Then you need extra structure.
2. **Setup Cost Dilemma:** Building the oracle and loading the data can cost more than the classical solution. Then the advantage is gone. QROM's O(N) cost is exactly this problem.
3. **Oracle Circularity:** In some problems, building the oracle means solving the problem itself.

**A different pattern, the SAT oracle:** In the [Qiskit Grover examples](https://qiskit-community.github.io/qiskit-algorithms/tutorials/07_grover_examples.html) and [Q# Katas SolveSATWithGrover](https://github.com/microsoft/QuantumKatas/blob/main/SolveSATWithGrover/Tasks.qs), the qubits are the variables themselves. The oracle cost depends on the formula, not on the dataset size. But this changes the question. It does not answer "which row in my dataset matches". It answers "which value combination makes the formula true". That combination may not exist in the dataset at all. If you add a check for "is this a real row", the cost goes back to O(N).

## 6. The Grover Dilemma Made Clear (Type A / Type B)

I understood this by reading Section 3 of the Liu paper. The Grover Dilemma is not about time. It is a one-time structure problem:

- S = the circuit space (2^n states for n qubits). D = the real data space (rows that exist).
- If |S| > |D|, the problem is Type A. The superposition then has "ghost" indices. These point to no real row. They can give false results and they waste amplitude.
- If |S| = |D|, the problem is Type B. There is no dilemma.

**In my project:** The wine dataset has 6,497 rows. It needs 13 qubits, which give 8,192 states. So there are 1,695 ghost indices (Type A). I cut the dataset to 2^n rows (4,096, and 64 or 8 in the tests). This made it Type B. Important: this fix is only about correctness. It does not make anything faster. The QROM cost of O(N) stays. So the total cost is still O(N), and the sqrt(N) advantage is lost in practice.

## 7. What the SAT Oracle Returns, and Why O(N) Cannot Be Avoided

I checked this with Aaronson's ["Read the Fine Print"](https://www.scottaaronson.com/papers/qml.pdf) (Nature Physics 2015) and the [PennyLane QROM page](https://pennylane.ai/demos/tutorial_intro_qrom):

- In the SAT approach, the measurement returns values (for example `quality=9, type=red`). It does not return a row index. The row identity is not in the circuit, so the measurement cannot give it. For a narrow query, the answer is just the query itself. Then there is no real search.
- Why does the membership check cost O(N)? The general way is: one equality test per row, joined with OR. The PennyLane page shows that QROM is a special case of the `Select` operator. So "a list of equality tests" and "QROM" are the same circuit with two names.
- The deep reason: the circuit is the only memory of the algorithm. A random set of N rows has no short description. You need about N x W bits, and they must live in the gate list. New papers (arXiv 2607.28260) lower this cost only when the data has special structure.

In short: The information must be in the query or in the circuit. If it is in neither, it is not in the measurement. If I put it in the query, I already know the answer. If I put it in the circuit, I pay O(N).

## 8. Quantization Analysis of the Dataset

Quantum comparators work with integer bits. So I scanned every column in the real data (min, max, decimal places):

- Ready to use: `quality` (integer), `type` (2 categories).
- Usable after scaling (9 columns): multiply by 10^d to get integers (d = number of decimal places).
- Two problem columns:
  - `alcohol`: the file has float noise with 14 decimals (records like `11.066666666666666`). Rounding to 2 decimals fixed it without loss (111 of 112 different values stayed).
  - `density`: its information lives in decimals 3 to 5. With 2 decimals the column dies (998 different values become 4). The right choice is 4 decimals (156 different values stay).

In pandas, I saved the scale factors in a dictionary called `scale`, on the same line where I quantize. I write query values in normal units (like `7.3`). A small helper function `q()` does the conversion. Inside it, `assert v.bit_length() <= weight[col]` stops values that do not fit the column. The error appears in Python, with a clear message, before anything goes to Q#.

## 9. Unknown Number of Solutions (M) and the BBHT Algorithm

The Grover iteration formula is `floor(pi/4 * sqrt(N/M))`. Here M is the number of rows that match the query. The query comes at runtime, so M is unknown at compile time. First I used a fixed M=1. Later I made M a parameter called `expectedMatches`. The user gives a guess for the number of matches. I do not count the answer with pandas and send it (then the search would have no meaning). A wrong guess does not break the result. It only lowers the probability.

**A rounding finding:** At first I wrote the formula with `Round`. For M=2 and N=8, the value pi/4 * sqrt(4) = 1.57 was rounded up to 2 turns. Two turns push the amplitude past its best point (theory: 25% at 2 turns, 100% at 1 turn). With `Floor` the circuit makes 1 turn, and the measurement lands 50/50 on the two matches. The formula in the literature also uses `Floor`.

**Source:** Boyer, Brassard, Hoyer, Tapp, ["Tight Bounds on Quantum Searching"](https://arxiv.org/abs/quant-ph/9605034) (1996), Section 4.

**The price of a wrong M (example from the paper):** With 1 solution in 2^20 states, 804 iterations find it almost always. But if there are really 4 solutions, the same 804 iterations find one with less than one in a million. Too many iterations turn the amplitude past its best point.

**The BBHT algorithm (works without knowing M):**

1. Set m = 1 and lambda = 6/5 (any value between 1 and 4/3 works).
2. Pick a random j between 0 and m-1.
3. Run oracle + diffuser j times, starting from the equal superposition.
4. Measure. If the result matches the query, stop.
5. If not, set m = min(lambda*m, sqrt(N)) and go to step 2.

The total work stays around O(sqrt(N/M)), even without knowing M. But BBHT needs a classical check after every try. That does not fit the single `target.submit(...)` job model. Every try would be a new Azure Quantum job. So I stayed with the fixed M=1.

## 10. QDK Compiler Bug: No BigInt Support in Partial Evaluation

**Symptom:** `qsharp.compile(op, queries, dataset)` failed with `Qdk.Qsc.PartialEval.Unexpected: unsupported LHS value: 7`.

**Root cause (I read the compiler source code, qsharp/qdk 1.31.0 and `main`):**

- The partial evaluator ([qsc_partial_eval/src/lib.rs](https://github.com/microsoft/qdk/blob/main/source/compiler/qsc_partial_eval/src/lib.rs)) supports Array, Result, Bool, Int, Double, Var, String and Pauli in binary operations. There is no BigInt case.
- The `Std.Arithmetic.ApplyIf*L` functions use BigInt math inside (`c + 1L` in `ApplyIfLessL`, `BitSizeL(c)` in `ApplyIfEqualL`). The moment my `IntAsBigInt(value)` enters such an operation, the compile fails.
- The `main` branch has the same gap. An upgrade does not help.

**Changing the target does not help either:** the error happens locally, before anything goes to Azure. QIR has no BigInt in any profile.

**My solution: never touch BigInt.** `ApplyControlledOnInt` uses only Int (I checked its source):

- For `==` and `!=`: use `ApplyControlledOnInt(value, X, slice, aux)` directly.
- For `<`, `>`, `<=`, `>=`: loop over all values that satisfy the condition. For example, for `x > value`, apply `ApplyControlledOnInt(v, X, slice, aux)` for every v in `value+1 .. 2^weight - 1`. Only one value can fire per basis state, so the logic is correct. The cost is O(2^weight) gates per query. QROM is much bigger anyway, so this is fine.

## 11. Cloud Tests: Scale Walls, QAT and Service Failures

**Scale wall 1, local compile:** The 4,096 rows x 119 bits version froze my computer during `qsharp.compile` (about 24.5M multi-controlled gates). The real limit was the qubit budget: total qubits = n + W + 1 (marker) + k (queries) = 12+119+1+2 = 134 qubits. Nothing can run that.

**My solution: put only the queried columns into QROM.** The oracle only reads the columns the query uses. I get the other columns later with pandas `iloc`, after the measurement. I cut the column list to 2 columns (fixed acidity 7 bits + quality 3 bits = W=10). Result: 24 qubits and 38,665 ccx at 64 rows.

**The Rigetti chain (all on the free `rigetti.sim.qvm` target):**

1. 64 rows: `QATTransformationFailed` (the error text has only settings, no real message).
2. Mini CCNOT test: success, 27 seconds from send to result. So the gate set is fine (QAT breaks `ccx` down itself). The problem is size.
3. 8 rows (21 qubits, 601 ccx): QAT passed (about 38 seconds to the error), but the QVM returned a Lisp error: `lparallel: MAKE-KERNEL`. The hosted QVM on Azure has no worker threads. I tried two times, hours apart. Same error both times. This is a service problem. I cannot fix it from my side. The Rigetti QVM has no noise, so with a working service it would show the same peak as my local run.

**Qubit limits (sources: [provider-quantinuum](https://learn.microsoft.com/en-us/azure/quantum/provider-quantinuum), [provider-rigetti](https://learn.microsoft.com/en-us/azure/quantum/provider-rigetti), [QVM GitHub](https://github.com/quil-lang/qvm)):**

| Target | Qubits | Note |
|---|---|---|
| `quantinuum.sim.h2-1sc/h2-2sc` | 56 | Free syntax checker, output is always 0 |
| `quantinuum.sim.h2-1e/h2-2e` | 56/32 | 56 only for stabilizer circuits; for my T-gate circuit it is 32 |
| `quantinuum.qpu.h2-1/h2-2` | 56 | Paid |
| `rigetti.sim.qvm` | not published | Memory limited; about 29-30 in practice |
| `rigetti.qpu.cepheus-1-108q` | 108 | Paid; a circuit this deep dies in noise |

My 24-qubit circuit fits every target. The Rigetti failure is a service problem, not a capacity problem.

## 12. End-to-End Validation and the Quantinuum Tests

**A note on `qsharp.run`:** the signature is `run(entry_expr, shots, *args)`. `shots` is the second position, before the arguments. This is different from `compile(entry_expr, *args)`.

**Local validation (success):** 64 rows x 2 columns (W=10, 24 qubits, 6 Grover iterations). Query: `fixed acidity == 7.3 AND quality >= 7`. Local simulator, 100 shots, total time 1 minute 20 seconds:

```text
[(7, 98), (33, 1), (54, 1)]
```

Index 7 came out in 98% of the shots. The pandas check for the same query also returned `[7]`. So the quantum answer and the classical answer agree. A random guess would give 1.6%. The theory says about 99% after 6 iterations, and the measurement matches it. The full chain worked: QROM + comparator + phase kickback + diffuser + iteration count.

**A hidden trap I found and closed, the column bit order (endianness):** `row_to_bits` wrote column values MSB-first. But `ApplyControlledOnInt` reads the slice little-endian. So the comparator really searched for the reversed bits of the query value. My first tests were safe by luck: 73 (`1001001`) and 7 (`111`) read the same in both directions (palindromes). A real test caught the bug: I gave the value 112 (`1110000`, not a palindrome) in an OR query. The circuit read it little-endian, saw 7, and never marked the row. The fix: `reversed(binary_str)` inside `row_to_bits`. After the fix, the regression test with 112 found the correct row.

**The Quantinuum tests:**

- `h2-1sc` syntax checker (free): it accepted the 8-row program (Succeeded; the output is always 0 by design). The advertised queue was 2 seconds, but my job waited more than 10 minutes. The 64-row program was rejected in seconds with `InternalError`. The mini CCNOT test passed, so I knew the service was alive. The rejection came from the program size.
- **Quota lesson:** A 100-shot job on the `h2-1e` emulator asked for 1,076 eHQC. The one-time quota is 1,000. So Azure rejected it with `NotEnoughQuota` before running. The cost is about `5 + shots x (1q + 10x2q + 5xmeas)/5000`. For my circuit that is about 10.7 eHQC per shot.
- With `shots=10` (about 112 eHQC) it ran. Queue plus run took about 1 hour (the advertised average queue was 53-72 minutes). **Result: a flat histogram** `{001:0.1, 011:0.2, 100:0.2, 111:0.2, 000:0.2, 110:0.1}`. The expected peak at `[1,1,1]` (index 7) is not there.
- **Why (the expected NISQ reality):** `h2-1e` uses a realistic noise model of the H2 machine. My 601 ccx become about 5,000 two-qubit gates. With 99.8% gate quality, the success chance is 0.998^5000, which is about 5x10^-5. The signal fully disappears into noise. This confirms the noise table from Section 5 by experiment: QROM based Grover at this depth is not practical on NISQ hardware. I saw it with my own circuit.

## 13. Logical Operators: AND/OR Support

At first I did not think about one question: when I put many conditions into the query list, do they act as AND or as OR? When I looked into it, I saw that the structure was an implicit AND (the marker flips only when all aux qubits are 1, because of the multi-controlled X). So I made the query format carry the logical operator in an explicit way. It now supports one level of logical operators: `(logical operator, [comparison list])`. The Q# type is `(Int, (Int, Int, Int, Int)[])`. 0 = AND (all conditions must hold), 1 = OR (at least one must hold). The outer part must be a tuple: a Python tuple maps to a Q# tuple, and a Python list maps to a Q# array.

- **AND:** a multi-controlled X on the aux qubits (`Controlled X(auxs, marker)`). The marker flips only when all aux qubits are 1.
- **OR (De Morgan):** "at least one is 1" = "NOT all are 0". I flip the aux qubits with X, apply the multi-controlled X (this gives NOR), and one extra X turns NOR into OR. The extra X acts on |-> as a global phase, so it does not hurt the result.
- **The XOR trap:** Do not build OR by writing two comparisons into the same aux qubit. If both conditions are true for the same row, the aux flips two times and goes back to 0. That is XOR, not OR. The correct way: one aux per comparison, then De Morgan.
- **The limit:** The format has one level only. A mixed formula like "a AND (b OR c)" needs a list of groups (CNF: OR inside a group, AND between groups). Q# has no recursive types, so deeper nesting is not possible anyway.

**Validation (local, 8 rows, 100 shots):**

- AND (`fixed acidity == 7.3 AND quality >= 7`): pandas `[7]`, Grover 95-98% on index 7.
- OR, M=1 (`fixed acidity == 11.2 OR quality == 4`): pandas `[3]`, Grover 91% on index 3.
- OR, M=2 (`fixed acidity == 11.2 OR quality >= 7`): pandas `[3, 7]`. With `expectedMatches=2`, Grover gave exactly 50/50 on `[3, 7]`. The same query with `expectedMatches=1` gave a flat histogram. This is the souffle problem (Section 9), seen in my own circuit. OR can easily match many rows, so the M guess matters even more with OR.

This work caught two bugs at the same time: the value 112 showed the endianness trap (Section 12), and the M=2 case showed the Round/Floor mistake in the iteration formula (Section 9).

## 14. Conclusion: What I Solved

In this project I solved this problem: **I built a working end-to-end system on a real dataset. The user gives a multi-condition query at runtime (column, operator, value; with ==, !=, >, <, >=, <=, and the logical operators AND/OR). The quantum circuit checks the conditions inside itself. Grover search finds the index of the matching row. Then pandas returns the full row.** This is different from the usual "database search" demos, which put the answer into the circuit before the search. Here the search really happens in the circuit: QROM loads the data, the conditions are compared on qubits, and the measurement finds the index.

The concrete problems I solved on the way:

1. I made the real dataset (winequality_combined.csv) fit onto qubits: cutting to 2^n rows (Type A to Type B), quantization analysis, a scale dictionary and a checked query converter.
2. I found the BigInt bug in the QDK compiler by reading its source code, and I went around it with a comparator design that uses only `ApplyControlledOnInt`.
3. I reduced the design from 134 qubits to 24 qubits with one decision: only queried columns go into QROM. This made the circuit compile and run.
4. I got the end-to-end result on the local simulator: 98% correct, and equal to the classical check.
5. On the cloud side I documented, with experiments: the Rigetti QVM service failure, Quantinuum's size-based rejection, the eHQC quota model, and the loss of the signal on the noise emulator.
6. I added the logical operators AND/OR to the query format (with a De Morgan circuit for OR). This work also closed the endianness trap with the `reversed()` fix, fixed the Round mistake in the iteration formula with `Floor`, and turned M into a user-guess parameter.

Overall: The mechanism is correct, and I proved it on an ideal simulator. But QROM's O(N) loading cost and NISQ noise stop this approach from giving a real speedup on today's hardware. The literature predicted this limit; I confirmed it with my own circuit. The endianness fix that was open before is now applied and tested with a non-palindrome value (112). No open items remain.
