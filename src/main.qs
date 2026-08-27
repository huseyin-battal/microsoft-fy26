namespace Main {
    import Std.Math.*;
    import Std.Convert.*;
    import Std.Arrays.*;
    import Std.Canon.*;
    import Std.Measurement.*;

    operation GroverSearchAlgorithm(queries : (Int, Int, Int, Int)[], dataset : Bool[][]) : Result[] {
        // her eleman: (offset, genislik, operatör, deger)
        let n = BitSizeI(Length(dataset) - 1); // indeks kübit sayısı veriden türetilir: 64 satır → 6, 4096 satır → 12
        let m = Length(dataset[0]); // satır genişliği (bit) veriden türetilir
        let idxCount = IntAsDouble(2^n);
        let resultCount = 1.0; // beklenen sonuç adedi 1.0 olarak belirledik.
        use rowQubits = Qubit[n];
        use columnQubits = Qubit[m];
        use marker = Qubit();
        // grover için marker-flip
        let iterationCount = Round((PI() / 4.0) * (Sqrt(idxCount / resultCount)));
        ApplyToEach(H, rowQubits);
        for _ in 1..iterationCount {
            within {
                //oracle
                H(marker);
                Z(marker);
            } apply {
                BuildQROM(rowQubits, columnQubits, dataset);
                CompareToQuery(columnQubits, queries, marker);
                Adjoint BuildQROM(rowQubits, columnQubits, dataset);
            }
            //diffuser
            within {
                ApplyToEachA(H, rowQubits);
            } apply {
                within {
                    ApplyToEachA(X, rowQubits);
                } apply {
                    Controlled Z(Most(rowQubits), Tail(rowQubits));
                }
            }

        }
        let result = MResetEachZ(rowQubits);
        return result;
    }

    operation BuildQROM(indexQubits : Qubit[], outputQubits : Qubit[], dataset : Bool[][]) : Unit is Adj + Ctl {
        for rowIdx in 0..Length(dataset) -1 {
            for colIdx in 0..Length(dataset[rowIdx]) - 1 {
                if dataset[rowIdx][colIdx] {
                    ApplyControlledOnInt(rowIdx, X, indexQubits, outputQubits[colIdx])
                }
            }
        }
    }

    operation CompareToQuery(outputQubits : Qubit[], queries : (Int, Int, Int, Int)[], marker : Qubit) : Unit is Adj + Ctl {
        use auxs = Qubit[Length(queries)];
        within {
            for i in 0..Length(queries)-1 {
                // OPS = {"==": 0, ">": 1, "<": 2, ">=": 3, "<=": 4, "!=":5}
                // Eşitsizlikler: koşulu sağlayan her klasik değer için ayrı pattern eşleşmesi.
                // Taban durumda en fazla biri tetiklenir, bu yüzden aux tam "koşul sağlanıyorsa" çevrilir.
                let (offset, weight, operator, value) = queries[i];
                let slice = outputQubits[offset..offset + weight - 1];
                if operator == 0 {
                    ApplyControlledOnInt(value, X, slice, auxs[i]);
                } elif operator == 1 {
                    for v in value + 1..2^weight - 1 {
                        ApplyControlledOnInt(v, X, slice, auxs[i]);
                    }
                } elif operator == 2 {
                    for v in 0..value - 1 {
                        ApplyControlledOnInt(v, X, slice, auxs[i]);
                    }
                } elif operator == 3 {
                    for v in value..2^weight - 1 {
                        ApplyControlledOnInt(v, X, slice, auxs[i]);
                    }
                } elif operator == 4 {
                    for v in 0..value {
                        ApplyControlledOnInt(v, X, slice, auxs[i]);
                    }
                } else {
                    X(auxs[i]);
                    ApplyControlledOnInt(value, X, slice, auxs[i]);
                }
            }
        } apply {
            Controlled X(auxs, marker);
        }




    }
}