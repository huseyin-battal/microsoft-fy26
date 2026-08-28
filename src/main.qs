namespace Main {
    import Std.Math.*;
    import Std.Convert.*;
    import Std.Arrays.*;
    import Std.Canon.*;
    import Std.Measurement.*;

    operation GroverSearchAlgorithm(queries : (Int, (Int, Int, Int, Int)[]), dataset : Bool[][], expectedMatches : Int) : Result[] {
        // GİRDİ: (mantıksal operatör, karşılaştırma listesi)
        // mantıksal operatör: 0 = AND (hepsi sağlanmalı), 1 = OR (en az biri sağlanmalı)
        // her karşılaştırma: (offset, genislik, operatör, deger)
        // expectedMatches: kullanıcının beklediği eşleşme sayısı tahmini (M). Tur sayısını belirler;
        // yanlış tahmin aşırı/eksik dönmeye (souffle) yol açar ama sonucu bozmaz, sadece olasılığı düşürür.
        let rowBitSize = BitSizeI(Length(dataset) - 1); // Satır kübitleri, verisetinin satır indislerinden türetilir: 8 satır → 3, 4096 satır → 12
        let colBitSize = Length(dataset[0]); // Sütun kübitleri, her satırın sahip olduğu bit-uzunluğundan belirlenir. 
        let rowsCount = IntAsDouble(2^rowBitSize); // Toplam satır sayısı
        let M = IntAsDouble(MaxI(1, expectedMatches)); // beklenen sonuç adedi parametreden gelir; 0 veya negatif verilirse 1'e sabitlenir.
        use rowQubits = Qubit[rowBitSize]; // 8 satır -> 3 kübit.
        use columnQubits = Qubit[colBitSize]; // colBitSize adet kübit.
        
        // Sorgu betikleri için Marker (işaret) kübiti kullanıyoruz. 
        // Sebep: Faz Geri Tepmesi ile aranan indisi "-" ile işaretlemek. 
        use marker = Qubit(); 
        
        
        // Grover Algoritma'sının istenen sonuçları bulabilmesi için tur sayısı formülü tanımlıyoruz.  
        // KAYNAK: BBHT: Boyer, Brassard, Høyer, Tapp, "Tight Bounds on Quantum Searching" (1996/98)
        // DİKKAT: Floor kullanıyoruz, Round değil. Ornek: M=2, N=8 icin pi/4 * sqrt(4) = 1.57;
        // Round 2 tura yuvarlar ve tepe noktasini asar (souffle), Floor ile 1 tur atilir ve olasilik maksimumda kalir.
        let iterationCount = Floor((PI() / 4.0) * (Sqrt(rowsCount / M))); // Üstel arama (BBHT) kullanmadık; M tahmini parametreden gelir.
        // M=1, N=8 ornegi: pi/4 * sqrt(8) = 2.22 -> 2 tur.
        
        // GROVER ALGORİTMASI
        ApplyToEach(H, rowQubits);
        for _ in 1..iterationCount {
            // Oracle (Kahin)
            within {
                H(marker); // |0⟩ → |+⟩ 
                Z(marker); // |+⟩ → |−⟩
            } apply {
                // "dataset" içerisindeki her bir satırı sahip olduğu İndis değerine göre bit-flip uygula ve durumları hafızaya yükle.
                BuildQROM(rowQubits, columnQubits, dataset); 

                // Durumu değişmiş columnQubits'ler ile sorguya başla. "marker" kübitinde "X|−⟩ = −|−⟩" oluştu ise sonuç bulundu demektir!
                CompareToQuery(columnQubits, queries, marker);

                // hafızaya yüklenen kübit durumları tümleştirilir ve bir önceki hallerine geri döndürülür.
                // Dolanıklık geri alınmış olur bu da rowQubits listesindeki kübitlerin columnQubits'ler ile olan dolanıklığını ortadan kaldırır. 
                // rowQubits içerisinde kalan: Faz bilgisi (+ mı yoksa - mi?)
                Adjoint BuildQROM(rowQubits, columnQubits, dataset);
            }
            // Diffuser: genlikleri ortalama etrafında yansıtır; eksi fazlı (işaretli) indeksin genliği büyür
            within {
                ApplyToEachA(H, rowQubits); // Taban değişimi: aradaki faz kapısını "ortalama etrafında yansıtma"ya çevirir
            } apply {
                within {
                    ApplyToEachA(X, rowQubits); // |0...0⟩ ↔ |1...1⟩ eşlemesi: Controlled Z'nin fazını |0...0⟩'a taşır
                } apply {
                    // Çok kontrollü Z: yalnız |11...1⟩ durumuna −1 fazı uygular
                    Controlled Z(Most(rowQubits), Tail(rowQubits));
                }
            }

        }
        // GROVER ALGORİTMASI
        let result = MResetEachZ(rowQubits);
        return result;
    }

    operation BuildQROM(rowQubits : Qubit[], columnQubits : Qubit[], dataset : Bool[][]) : Unit is Adj + Ctl {
        for rowIdx in 0..Length(dataset) -1 {
            for colIdx in 0..Length(dataset[rowIdx]) - 1 {
                if dataset[rowIdx][colIdx] {
                    ApplyControlledOnInt(rowIdx, X, rowQubits, columnQubits[colIdx])
                }
            }
        }
    }

    operation CompareToQuery(columnQubits : Qubit[], queries : (Int, (Int, Int, Int, Int)[]), marker : Qubit) : Unit is Adj + Ctl {
        let (logicalOp, comparisons) = queries; // logicalOp: 0 = AND, 1 = OR
        use auxs = Qubit[Length(comparisons)]; // her karşılaştırma için bir yardımcı (aux) kübit.
        within {
            for i in 0..Length(comparisons)-1 {
                // COMP_OPS = {"==": 0, ">": 1, "<": 2, ">=": 3, "<=": 4, "!=":5}
                // Eşitsizlikler: koşulu sağlayan her klasik değer için ayrı pattern eşleşmesi.
                // Taban durumda en fazla biri tetiklenir, bu yüzden aux tam "koşul sağlanıyorsa" çevrilir.
                let (offset, weight, operator, value) = comparisons[i];
                
                // .ipynb dosyasında tanımladığımız weight ve offset değişkenleri ile her sütuna karşılık gelen bit-genişliğine
                // göre ona karşılık gelen kübitler seçilir ve "slice" olarak adlandırılır. 
                let slice = columnQubits[offset..offset + weight - 1];
                
                if operator == 0 { // operatör "eşittir" ise;
                    // koşul değeri olan "value", slice kübitlerinin tam sayı değerini sağlamak zorundadır. 
                    ApplyControlledOnInt(value, X, slice, auxs[i]); 
                } elif operator == 1 { // operatör "büyüktür" ise;
                    // value + 1 ile 2^{sutun_genisligi} - 1 arasında olan tüm tamsayılar karşılaştırılır. 
                    // EĞER v değeri, slice içerisindeki bit durumlarına karşılık geliyorsa "büyüktür" işareti başarılıdır.
                    
                    // MANTIK: Q#'ta "büyüktür" mantığı, oluşan "BigInt" bug'ından dolayı bu şekilde tanımlanmıştır (4. operatör'e kadar)
                    // SEBEP: Biz aranan değerin slice içerisindeki kübit durumunu SADECE kendisinden yüksek değerlerle değerlendirmek istiyoruz.
                    for v in value + 1..2^weight - 1 {
                        ApplyControlledOnInt(v, X, slice, auxs[i]);
                    }
                } elif operator == 2 { // operatör "küçüktür" ise;
                    // 0'dan value -1'e kadar olan tüm tam sayı değerlerinin slice kübit durumlarına eşit olup olmadıklarını öğrenmek istiyoruz.
                    // "büyüktür" işareti ile benzer mantık; kendisi hariç herhangi v değeri sağlıyor mu? Ancak, tavan değer bu sefer kendisinin bir eksiği: "value - 1"
                    for v in 0..value - 1 {
                        ApplyControlledOnInt(v, X, slice, auxs[i]);
                    }
                } elif operator == 3 { // operatör: "büyük eşittir" ise;
                    // "büyüktür" operatöründen tek farkı saymaya kıyaslanan kendi "value" değerinden başlamamızdır
                    // SEBEP: v, value değerine eşit YA DA büyük olan slice değerlerini auxs[i]'ye uygulasın diye. 
                    for v in value..2^weight - 1 {
                        ApplyControlledOnInt(v, X, slice, auxs[i]);
                    }
                } elif operator == 4 { // operatör: "küçük eşittir" ise;
                    // "küçüktür" işareti ile benzer mantık; bu sefer taban değer direkt kendisi: v, 0 da olabilir "value" da olabilir.
                    for v in 0..value {
                        ApplyControlledOnInt(v, X, slice, auxs[i]);
                    }
                } else { // operatör: "eşit değildir" ise;
                    // Varsayılan durumu |0⟩ olan i'nci auxs dummy'sini bit-flip yaparız. 
                    // MANTIK: "eşittir" operatöründen tek farkı sonucun "tam tersi" olması gerektiğidir.
                    // Mesela, value tam sayı değeri ile slice kübiti arasındaki değerler eşleşiyorsa bu FALSE olmalıdır. 
                    // 1 olacak olan i'nci auxs dummy'sini 0'a çeviriyoruz. value ile slice eşleşmiyor ise bu TRUE olur çünkü istenen durum eşit olmamalarıdır.
                    X(auxs[i]);
                    ApplyControlledOnInt(value, X, slice, auxs[i]);
                }
            }
        } apply {
            // SON AŞAMA: aux'lardaki koşul sonuçları mantıksal operatöre göre marker'a işlenir.
            if logicalOp == 0 {
                // AND: tüm aux'lar 1 ise marker çevrilir (çok kontrollü X).
                Controlled X(auxs, marker);
            } else {
                // OR (De Morgan): "en az biri 1" = "hepsi 0 DEĞİL".
                // Aux'lar ters çevrilip çok kontrollü X uygulanır: marker yalnız hepsi 0 iken çevrilmiş olur (NOR).
                // Sondaki koşulsuz X, NOR'u OR'a tamamlar; |−⟩ üzerindeki etkisi genel faz olduğu için sonucu bozmaz.
                within {
                    ApplyToEachA(X, auxs);
                } apply {
                    Controlled X(auxs, marker);
                }
                X(marker);
            }
        }




    }
}