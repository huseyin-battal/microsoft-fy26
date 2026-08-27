namespace Main{
    import Std.Math.*;
    import Std.Convert.*;
    import Std.Arithmetic.*;
    import Std.Arrays.*;
    import Std.Canon.*;
    import Std.Measurement.*;

    operation GroverSearchAlgorithm(queries:(Int, Int, Int, Int)[], dataset:Bool[][]): Result[]{
        // her eleman: (offset, genislik, operatör, deger)
        let n = 12; // varsayılan indis değeri için sabit kübit. log2(4096) = 12 kübit
        let m = 119; // Verisetinin sütunları sabit 119 bit genişlik kaplıyor.
        let idxCount = IntAsDouble(2^n);
        let resultCount = 1.0; // beklenen sonuç adedi 1.0 olarak belirledik.
        use rowQubits = Qubit[n];
        use columnQubits = Qubit[m];
        use marker = Qubit();
        // grover için marker-flip
        let iterationCount = Round((PI()/4.0) * (Sqrt(idxCount/resultCount)));
        ApplyToEach(H, rowQubits);
        for _ in 1..iterationCount{
            within{ //oracle
                H(marker);
                Z(marker);
            }
            apply{
                BuildQROM(rowQubits, columnQubits, dataset);
                CompareToQuery(columnQubits, queries, marker);
                Adjoint BuildQROM(rowQubits, columnQubits, dataset);
            }
            //diffuser
            within{
                ApplyToEachA(H, rowQubits);
            }apply{
                within{
                    ApplyToEachA(X, rowQubits);
                }apply{
                    Controlled Z(Most(rowQubits), Tail(rowQubits));
                }
            }

        }
        let result = MResetEachZ(rowQubits);
        return result;
    }

    operation BuildQROM(indexQubits: Qubit[], outputQubits: Qubit[], dataset:Bool[][]): Unit is Adj + Ctl{
        for rowIdx in 0..Length(dataset) -1{
            for colIdx in 0..Length(dataset[rowIdx]) - 1{
                if dataset[rowIdx][colIdx]{
                    ApplyControlledOnInt(rowIdx,X,indexQubits,outputQubits[colIdx])
                }
            }
        }
    }

    operation CompareToQuery(outputQubits: Qubit[], queries: (Int, Int, Int, Int)[], marker:Qubit): Unit is Adj + Ctl{
        use auxs = Qubit[Length(queries)];
        mutable i = 0;
        within{
            for i in 0..Length(queries)-1{
                // OPS = {"==": 0, ">": 1, "<": 2, ">=": 3, "<=": 4, "!=":5}
                //queries
                let (offset, weight, operator, value) = queries[i];
                if operator == 0{
                    ApplyIfEqualL(X, IntAsBigInt(value), outputQubits[offset..offset+weight-1], auxs[i]);
                }
                elif operator == 1{ // x > value ⇔ value < x, bu yüzden ApplyIfLessL kullanılıyor (c OP x sırası ters)
                    ApplyIfLessL(X, IntAsBigInt(value), outputQubits[offset..offset+weight-1], auxs[i]);
                }
                elif operator == 2{
                    ApplyIfGreaterL(X, IntAsBigInt(value), outputQubits[offset..offset+weight-1], auxs[i]);
                }
                elif operator == 3{
                    ApplyIfLessOrEqualL(X, IntAsBigInt(value), outputQubits[offset..offset+weight-1], auxs[i]);
                }
                elif operator == 4{
                    ApplyIfGreaterOrEqualL(X, IntAsBigInt(value), outputQubits[offset..offset+weight-1], auxs[i]);
                }
                else{
                    X(auxs[i]);
                    ApplyIfEqualL(X, IntAsBigInt(value), outputQubits[offset..offset+weight-1], auxs[i])
                }
            }

        }apply{

            Controlled X(auxs, marker);
        }
        
        
        
        
    }
}