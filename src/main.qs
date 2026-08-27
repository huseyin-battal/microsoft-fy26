namespace Main{
    import Std.Math.LogOf2;
    operation GroverSearchAlgorithm(queries:(Int, Int, Int, Int)[], dataset:Bool[][]): Result[]{
        // her eleman: (offset, genislik, operatör, deger)
        use indexQubits = Qubit[12];
        BuildQROM(indexQubits, )
        use q = Qubit();
        let r = M(q);
        Reset(q);
        return [r];
    }

    operation BuildQROM(indexQubits: Qubit[], outputQubits: Qubit[], dataset:Bool[][]): Unit is Adj + Ctl{
        
    }
}