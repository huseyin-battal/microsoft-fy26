# Q# ile Gerçek Veri Setinde Grover Araması (Azure Quantum)

Bu proje, **Microsoft FY26 Yaz Stajı** dönemi kapsamında uygulanmış, araştırılmış ve tüm bulguları belgelenmiştir.

## Amaç

Grover Arama Algoritmasını oyuncak örneklerin ötesine taşıyıp gerçek bir veri seti (UCI Wine Quality, 6.497 gözlem) üzerinde çok koşullu sorgu çalıştırmak: "fixed acidity == 7.3 VE quality >= 7" gibi bir sorguyu kuantum devresi içinde değerlendirip eşleşen satırın indeksini ölçümle bulmak, ardından satırın tamamını pandas ile kullanıcıya göstermek.

## Nasıl Çalışıyor

1. **Ön işleme (Python/pandas):** Veri seti 2^n satıra kırpılır (Grover Dilemma, Type A'dan kaçınmak için), sütunlar tam sayıya quantize edilir, her satır sabit genişlikte bit dizisine çevrilir.
2. **QROM (Q#):** Veri seti, indekse koşullu kontrollü kapılarla devreye gömülür; sorgulanan sütunlar kübitlere yüklenir.
3. **Sorgu oracle'ı (Q#):** (offset, genişlik, operatör, değer) dörtlüleri çalışma zamanında gönderilir; ==, !=, >, <, >=, <= operatörleri devre içinde değerlendirilir ve eşleşen indeksin fazı işaretlenir.
4. **Grover döngüsü:** Oracle + diffuser, pi/4 * sqrt(N/M) kez tekrarlanır; ölçüm eşleşen satırın indeksini döndürür.
5. **Sonuç:** Python, ölçülen indeksi pandas.iloc ile gerçek satıra çevirir.

## Öne Çıkan Sonuçlar

- **Yerel simülatör (doğruluk kanıtı):** 64 satır x 2 sütun, 24 kübit, 6 iterasyon; 100 shot'ın %98'i doğru indekste yoğunlaştı ve klasik pandas kontrolüyle birebir örtüştü.
- **Bulut (NISQ gerçeği):** Quantinuum h2-1e gürültü modelli emülatöründe aynı devre düz histogram döndürdü; ~5.000 iki kübitlik kapı derinliği, mevcut donanım gürültüsünde sinyali tamamen eritiyor. Literatürün öngördüğü "QROM yükleme maliyeti + NISQ gürültüsü" sınırı deneysel olarak doğrulandı.
- **Altyapı bulguları:** Rigetti QVM servis hatası, Quantinuum kota modeli (eHQC), QDK derleyicisinde BigInt hatası, hedeflerin kübit sınırları ve daha fazlası [bulgular.md](bulgular.md) dosyasında ayrıntılı belgelendi.

## Depo Yapısı

| Dosya | İçerik |
|---|---|
| `main.ipynb` | Uçtan uca boru hattı: veri hazırlama, sorgu kurma, derleme, yerel/bulut çalıştırma |
| `src/main.qs` | Q# devresi: QROM, sorgu oracle'ı, diffuser, Grover döngüsü |
| `data/` | Veri setleri (UCI Wine Quality, Titanic ve türetilmiş alt kümeler) |
| `bulgular.md` | Araştırma ve deney bulgularının tamamı (Türkçe) |

## Kurulum ve Çalıştırma

```bash
python -m venv .venv
.venv/bin/pip install qsharp qdk azure-quantum pandas python-dotenv ipykernel
```

Azure bulut hedefleri için workspace Resource ID değerini `.env` dosyasına `RESOURCE_ID` olarak ekleyin ve `az login` ile oturum açın. Yalnızca yerel simülasyon için Azure hesabı gerekmez; `main.ipynb` içindeki yerel doğrulama hücresi yeterlidir.

## Lisans

Bu proje [MIT lisansı](LICENSE) ile lisanslanmıştır ve herkese açık (public) olarak yayınlanmaktadır.

## Teşekkür

Bu staj dönemi boyunca değerli yönlendirmeleri ve desteği için **Barbaros Günay**'a içten teşekkürlerimi sunarım.

## Yazar

**Hüseyin Battal**

---

# Grover Search on a Real Dataset with Q# (Azure Quantum)

This project was implemented, researched and fully documented as part of the **Microsoft FY26 Summer Internship** period.

## Purpose

Taking Grover's Search Algorithm beyond toy examples: running a multi-condition query such as "fixed acidity == 7.3 AND quality >= 7" on a real dataset (UCI Wine Quality, 6,497 observations), evaluating the query inside the quantum circuit, measuring the index of the matching row, and then presenting the full row to the user via pandas.

## How It Works

1. **Preprocessing (Python/pandas):** The dataset is trimmed to 2^n rows (to avoid the Type A Grover Dilemma), columns are quantized to integers, and each row is converted into a fixed-width bit array.
2. **QROM (Q#):** The dataset is embedded into the circuit with index-conditioned controlled gates; queried columns are loaded onto qubits.
3. **Query oracle (Q#):** (offset, width, operator, value) tuples are passed at runtime; the operators ==, !=, >, <, >=, <= are evaluated in-circuit and the phase of the matching index is marked.
4. **Grover loop:** Oracle + diffuser repeated pi/4 * sqrt(N/M) times; measurement returns the index of the matching row.
5. **Result:** Python maps the measured index back to the actual row via pandas.iloc.

## Key Results

- **Local simulator (correctness proof):** 64 rows x 2 columns, 24 qubits, 6 iterations; 98% of 100 shots concentrated on the correct index, matching the classical pandas check exactly.
- **Cloud (NISQ reality):** On Quantinuum's noise-modeled h2-1e emulator the same circuit returned a flat histogram; a depth of ~5,000 two-qubit gates completely dissolves the signal under current hardware noise. The "QROM loading cost + NISQ noise" limit predicted by the literature was confirmed experimentally.
- **Infrastructure findings:** Rigetti QVM service failure, Quantinuum quota model (eHQC), a BigInt bug in the QDK compiler, per-target qubit limits and more are documented in detail in [bulgular.md](bulgular.md) (in Turkish).

## Repository Structure

| File | Content |
|---|---|
| `main.ipynb` | End-to-end pipeline: data preparation, query building, compilation, local/cloud execution |
| `src/main.qs` | Q# circuit: QROM, query oracle, diffuser, Grover loop |
| `data/` | Datasets (UCI Wine Quality, Titanic and derived subsets) |
| `bulgular.md` | Complete research and experiment findings (Turkish) |

## Setup and Running

```bash
python -m venv .venv
.venv/bin/pip install qsharp qdk azure-quantum pandas python-dotenv ipykernel
```

For Azure cloud targets, add your workspace Resource ID to a `.env` file as `RESOURCE_ID` and sign in with `az login`. No Azure account is needed for local simulation only; the local validation cell in `main.ipynb` is sufficient.

## License

This project is licensed under the [MIT License](LICENSE) and is published publicly.

## Acknowledgements

My sincere thanks to **Barbaros Günay** for the valuable guidance and support provided throughout this internship period.

## Author

**Hüseyin Battal**
