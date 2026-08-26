# En Verimli 10 Sıralama Algoritması — 4096 Satır Üzerinden

Firecrawl ile taranan kaynaklar: [Sort & Visualize — Which Sorting Algorithm Is Fastest?](https://sortandvisualize.com/blog/which-sorting-algorithm-is-fastest/), [GeeksforGeeks — Time Complexities of all Sorting Algorithms](https://www.geeksforgeeks.org/dsa/time-complexities-of-all-sorting-algorithms/).

**Neden 4096?** Bu projede wine veri setini hayalet-index oluşmasın diye 2¹² = 4096 satıra kırpma fikrini konuşmuştuk; bu dosyadaki tüm hesaplar aynı N üzerinden yapılmıştır. `log₂(4096) = 12` olduğu için sayılar elle doğrulanabilir kadar temizdir:

| Büyüklük sınıfı | İşlem sayısı @ N=4096 |
|---|---|
| O(N + k), k=11 | ≈ 4.100 |
| O(N·d), d=3 hane | ≈ 12.300 |
| O(N log N) = 4096 × 12 | ≈ 49.152 |
| O(N^1.25) (Shell, ampirik) | ≈ 32.768 |
| O(N²/4) (ortalama, ekleme türü) | ≈ 4.194.304 |
| O(N²) (en kötü) | ≈ 16.777.216 |

Zaman karşılığı (kabaca): derlenmiş kodda ~10⁹ basit işlem/sn, saf Python'da ~10⁷ işlem/sn varsayımıyla. Örnek: O(N log N) ≈ 49 µs (C) / 5 ms (Python); O(N²) ≈ 17 ms (C) / 1,7 s (Python). **"Kazanç" sütunu, O(N²) en kötü duruma (16,8M işlem) göre kaç kat daha az işlem yapıldığını gösterir.**

> Önemli dürüstlük notu (kaynakların da vurguladığı): "En hızlı sıralama algoritması" tek başına anlamlı bir soru değildir — veri tipine ve dağılımına bağlıdır. Aşağıdaki sıralama, **"4096 satır, sınırlı aralıklı tam sayı anahtarlar (örn. wine quality 0-10), rastgele dağılım"** senaryosu içindir. İlk 3 algoritma karşılaştırma yapmadan sıraladığı için O(N log N) alt sınırına tabi değildir — "hile" değil, farklı hesap modelidir: alt sınır yalnızca karşılaştırma tabanlı algoritmalar için geçerlidir.

---

## 1. Counting Sort — O(N + k)

- **@4096:** k=11 (quality 0-10 gibi dar aralık) için ≈ **4.107 işlem** → O(N²)'ye göre **~4.000×**, O(N log N)'e göre bile **~12×** kazanç.
- **Neden verimli:** Hiç karşılaştırma yapmaz. Her anahtarın kaç kez geçtiğini bir sayaç dizisine yazar (tek geçiş), sonra sayaçlardan çıktıyı doğrudan üretir (ikinci geçiş). İki lineer geçiş, dallanma yok, önbellek dostu ardışık erişim.
- **Şartı:** Anahtar aralığı (k) küçük ve tam sayı olmalı. k ≫ N olursa (örn. 64-bit rastgele anahtarlar) sayaç dizisi devasa olur ve avantaj tamamen çöker — bu yüzden "her zaman en hızlı" değil, "şartı sağlanınca en hızlı".
- **Kararlı (stable):** Evet. Ek bellek: O(k).

## 2. Radix Sort (LSD) — O(N · d)

- **@4096:** 12-bit anahtarları 4-bit'lik 3 haneye bölersek 3 geçiş × (4096 + 16) ≈ **12.336 işlem** → O(N²)'ye göre **~1.360×**, O(N log N)'e göre **~4×** kazanç.
- **Neden verimli:** Counting sort'u hane hane uygular — anahtar aralığı büyük olsa bile (k'yi hanelere bölerek) lineer davranışı korur. Karşılaştırma alt sınırını, karşılaştırma yapmayarak aşar.
- **Şartı:** Sabit genişlikli anahtarlar (tam sayı, sabit uzunlukta string). Hane sayısı d, log(k)'ye bağlıdır; d küçükse N log N'i rahatça geçer (kaynak: Sort & Visualize, "can legitimately beat the O(n log n) lower bound").
- **Kararlı:** Evet (LSD varyantı). Ek bellek: O(N + hane tabanı).

## 3. Bucket Sort — O(N + k) ortalama

- **@4096:** Düzgün (uniform) dağılımda ≈ **8-12 bin işlem** (dağıtım + kova içi mini sıralamalar) → O(N²)'ye göre **~1.500-2.000×** kazanç.
- **Neden verimli:** Veriyi değer aralığına göre kovalara dağıtır; her kova ortalamada ~1 eleman alır, kova içi sıralama neredeyse bedavaya gelir.
- **Şartı ve riski:** Verim tamamen dağılım varsayımına bağlı. Çarpık (skewed) veride tüm elemanlar tek kovaya yığılır ve en kötü durum O(N²)'ye düşer — ilk üçlü içinde varsayımı en kırılgan olan budur, bu yüzden counting/radix'in altında.
- **Kararlı:** Kova içi sıralamaya bağlı. Ek bellek: O(N).

## 4. Pdqsort / Introsort (hibrit quicksort) — O(N log N) garantili

- **@4096:** ≈ **49.152 karşılaştırma**, pratikte karşılaştırma tabanlıların en düşük sabit çarpanı → O(N²)'ye göre **~341×** kazanç.
- **Neden verimli:** Quicksort'un önbellek dostu, yerinde (in-place) bölümlemesini alır; kötü pivot dizisi tespit edilirse heapsort'a kaçarak O(N²) riskini tamamen kapatır (introspection); küçük parçalarda (≈16-32 eleman altı) insertion sort'a düşer. Pdqsort ayrıca tekrarlı/desenli girdileri algılayıp lineere yaklaşır. C++ `std::sort` (introsort) ve Rust `sort_unstable` (pdqsort) bunun için bunları kullanır.
- **Genel anahtar tipi:** Her şeyi sıralar (karşılaştırılabilir olsun yeter) — ilk üçlünün "tam sayı anahtar" şartı yok. **Anahtar tipi kısıtı olmayan senaryoda gerçek 1 numara budur.**
- **Kararlı:** Hayır. Ek bellek: O(log N) yığın.

## 5. Timsort — O(N log N), sıralıya yakın veride O(N)

- **@4096:** Rastgele veride ≈ 49.152 karşılaştırma (sabit çarpanı introsort'tan biraz yüksek); **sıralıya yakın veride ≈ 4.095 karşılaştırmaya kadar düşer** (tek geçiş) → o senaryoda O(N log N)'e göre bile 12× kazanç.
- **Neden verimli:** Verideki hazır sıralı "koşuları" (runs) tespit eder, kısa koşuları insertion sort ile uzatır, koşuları merge eder. Gerçek dünya verisi nadiren tam rastgeledir — kısmi düzen her yerdedir, Timsort bunu paraya çevirir. Python `sorted()`, Java (nesneler), Swift varsayılanı budur.
- **Kararlı:** Evet — eşit anahtarların satır sırasını korur (bir CSV'de aynı quality'li satırların orijinal sırası bozulmaz; veri çerçevesi işlerinde önemli).
- Ek bellek: O(N).

## 6. Quicksort (saf, rastgele pivot) — O(N log N) ortalama

- **@4096:** Ortalama ≈ 1,39 × N log₂N ≈ **68.300 karşılaştırma** → O(N²)'ye göre **~245×** kazanç.
- **Neden verimli:** Yerinde bölümleme ardışık bellek erişimiyle çalışır — önbellek davranışı mükemmel; ortalama sabit çarpanı merge sort'tan düşük.
- **Neden 4. sıradaki hibritlerin altında:** Korumasızdır — kötü pivot diziliminde (örn. zaten sıralı girdi + ilk-eleman pivotu) O(N²)'ye çöker: 4096 satırda 68 bin yerine 16,8 milyon işlem. Hibritler tam da bu riski kapatmak için var.
- **Kararlı:** Hayır. Ek bellek: O(log N).

## 7. Merge Sort — O(N log N) garantili

- **@4096:** Her durumda ≈ **49.152-53.000 karşılaştırma** + N log N eleman kopyası → O(N²)'ye göre **~341×** kazanç, ama kopyalama yükü nedeniyle pratikte quicksort'tan ~%20-30 yavaş.
- **Neden verimli:** En kötü durumu bile N log N — öngörülebilirliğin şampiyonu. Ardışık erişim deseni diskten/ağdan sıralamaya (external sort) doğal uyar; RAM'e sığmayan veride hâlâ standart çözümdür.
- **Kararlı:** Evet. Ek bellek: O(N) — pratikte ana dezavantajı bu.

## 8. Heapsort — O(N log N) garantili

- **@4096:** ≈ 2 × N log₂N ≈ **98.300 işlem** → O(N²)'ye göre **~170×** kazanç; pratikte quicksort'tan ~2-3× yavaş.
- **Neden verimli ama listede geride:** En kötü durum garantisi + O(1) ek bellek — bu ikili kombinasyonu başka kimse vermez. Ancak heap yapısındaki atlama desenli (2i, 2i+1) bellek erişimi önbelleği sürekli ıskalatır; asimptotik eşitken pratik sabiti yüksektir. Bu yüzden tek başına değil, introsort'un "acil durum freni" olarak yaşar.
- **Kararlı:** Hayır. Ek bellek: O(1).

## 9. Shellsort — aralık dizisine göre ~O(N^1.25)

- **@4096:** İyi aralık dizisiyle (Ciura vb.) ampirik ≈ N^1.25 = **32.768 civarı taşıma** (karşılaştırma sabiti daha yüksek) → O(N²)'ye göre **~500×** kazanç kağıt üstünde, pratikte N log N ailesiyle başa baş ama tutarsız.
- **Neden verimli:** Insertion sort'u önce büyük adımlarla çalıştırıp elemanları hedeflerine "ışınlar", son geçişte neredeyse sıralı diziyi ucuza bitirir. Özyineleme yok, yığın yok, O(1) bellek — gömülü sistemlerde hâlâ tercih edilir.
- **Neden geride:** Karmaşıklığı aralık dizisine bağlı ve kesin analizi hâlâ açık problem; en kötü durumda O(N²)'ye kadar sarkabilir. Öngörülemezlik, modern kütüphanelerin onu terk etme sebebidir.
- **Kararlı:** Hayır. Ek bellek: O(1).

## 10. Tree Sort (dengeli BST ile) — O(N log N)

- **@4096:** ≈ 49.152 karşılaştırma ama her ekleme düğüm tahsisi + işaretçi takibi demek → O(N²)'ye göre **~341×** kazanç kağıt üstünde; pratikte tahsis/önbellek yükü onu bu listenin dibine iter. Dengesiz (dengelemesiz) varyantı sıralı girdide O(N²)'ye çöker.
- **Neden yine de listede:** Sıralamayı **artımlı** yapabilen tek aday — veri akar halde gelirken yapı her an sıralıdır; araya ekleme/silme O(log N)'dir. "Bir kez sırala" değil "sıralı tut" problemi için doğru cevaptır.
- **Kararlı:** Uygulamaya bağlı. Ek bellek: O(N) düğüm yükü.

---

## Listeye Giremeyenler (ve neden)

- **Insertion Sort:** Rastgele 4096 satırda ortalama N²/4 ≈ **4,2 milyon işlem** — diskalifiye. Ama ≤16-32 elemanda ve sıralıya-yakın girdide (O(N+k), k = yer değiştirmiş eleman sayısı) **rakipsizdir**; 4-5-9 numaralı algoritmaların hepsi içeride onu çalıştırır. "Yavaş algoritma" değil, "yanlış ölçekte kullanılınca yavaş" algoritmadır.
- **Bubble / Selection Sort:** Her durumda O(N²); selection sort mevcut düzene tamamen kördür (sıralı veride bile aynı 8,4M karşılaştırma). Eğitim değeri dışında kullanım alanı yok.

## Özet Tablo (hızlıdan yavaşa, N=4096)

| # | Algoritma | İşlem @4096 | O(N²)'ye kazanç | Şart / Not |
|---|---|---|---|---|
| 1 | Counting Sort | ~4.100 | ~4.000× | Dar tam sayı aralığı (k küçük) |
| 2 | Radix Sort (LSD) | ~12.300 | ~1.360× | Sabit genişlikli anahtar |
| 3 | Bucket Sort | ~8-12 bin | ~1.500× | Düzgün dağılım varsayımı |
| 4 | Pdqsort/Introsort | ~49.200 | ~341× | Genel amaçlı gerçek şampiyon |
| 5 | Timsort | ~49.200 (→4.100 sıralıda) | ~341× | Kararlı; kısmi düzeni sömürür |
| 6 | Quicksort (saf) | ~68.300 | ~245× | O(N²) riski korumasız |
| 7 | Merge Sort | ~49-53 bin + kopya | ~341× | Kararlı, garantili, O(N) bellek |
| 8 | Heapsort | ~98.300 | ~170× | O(1) bellek + garanti; önbellek düşmanı |
| 9 | Shellsort | ~32.800 (ampirik) | ~500× kağıtta | Aralık dizisine bağlı, öngörüsüz |
| 10 | Tree Sort | ~49.200 + tahsis | ~341× kağıtta | Artımlı sıralamanın tek adayı |

**Pratik sonuç:** 4096 satırlık wine alt kümesini quality'ye göre sıralayacaksan doğru cevap Counting Sort'tur (k=11) — ama gerçekte `df.sort_values("quality")` yazarsın ve pandas'ın altındaki tuned hibrit, farkı milisaniyenin altında zaten kapatır. Kaynakların ortak tavsiyesi de bu: profilleme aksini kanıtlayana kadar dilin yerleşik sıralamasını kullan.
