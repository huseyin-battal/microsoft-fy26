namespace Main {
    import Std.Math.*;
    import Std.Convert.*;
    import Std.Arrays.*;
    import Std.Canon.*;
    import Std.Measurement.*;

    operation GroverSearchAlgorithm(queries : (Int, Int, Int, Int)[], dataset : Bool[][]) : Result[] {
        // GİRDİ: (offset, genislik, operatör, deger)
        let rowBitSize = BitSizeI(Length(dataset) - 1); // Satır kübitleri, verisetinin satır indislerinden türetilir: 8 satır → 3, 4096 satır → 12
        let colBitSize = Length(dataset[0]); // Sütun kübitleri, her satırın sahip olduğu bit-uzunluğundan belirlenir. 
        let rowsCount = IntAsDouble(2^rowBitSize); // Toplam satır sayısı
        let M = 1.0; // beklenen sonuç adedi 1 olarak belirledik.
        use rowQubits = Qubit[rowBitSize]; // 8 satır -> 3 kübit.
        use columnQubits = Qubit[colBitSize]; // colBitSize adet kübit.
        
        // Sorgu betikleri için Marker (işaret) kübiti kullanıyoruz. 
        // Sebep: Faz Geri Tepmesi ile aranan indisi "-" ile işaretlemek. 
        use marker = Qubit(); 
        
        
        // Grover Algoritma'sının istenen sonuçları bulabilmesi için tur sayısı formülü tanımlıyoruz.  
        // KAYNAK: BBHT: Boyer, Brassard, Høyer, Tapp, "Tight Bounds on Quantum Searching" (1996/98)
        let iterationCount = Round((PI() / 4.0) * (Sqrt(rowsCount / M))); // M=1 ise dönecek sonuç bellidir. Üstel arama kullanmadık.
        // 2,2214414690791831235079404950303 = 2 tur saysı.
        
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

    operation CompareToQuery(columnQubits : Qubit[], queries : (Int, Int, Int, Int)[], marker : Qubit) : Unit is Adj + Ctl {
        use auxs = Qubit[Length(queries)]; // 2 sorgu betiği belirledik. Liste şeklinde 2 adet kübit'i dummy olarak ayarladık.
        within {
            for i in 0..Length(queries)-1 {
                // OPS = {"==": 0, ">": 1, "<": 2, ">=": 3, "<=": 4, "!=":5}
                // Eşitsizlikler: koşulu sağlayan her klasik değer için ayrı pattern eşleşmesi.
                // Taban durumda en fazla biri tetiklenir, bu yüzden aux tam "koşul sağlanıyorsa" çevrilir.
                let (offset, weight, operator, value) = queries[i];
                
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
            // SON AŞAMA: auxs dummy'leri ile işaretlenen durumlar, marker'a işlenmek için CCNOT'a gönderilir.
            Controlled X(auxs, marker);
        }




    }
}