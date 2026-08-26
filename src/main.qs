namespace Main{
    operation GroverSearchAlgorithm(queries:(Int, Int, Int, Int)[], dataset:Bool[][]): Result[]{
        // her eleman: (offset, genislik, operatör, deger)
        
        use q = Qubit();
        let r = M(q);
        Reset(q);
        return [r];
    }

    operation BuildQROM(indexQubits: Qubit[], outputQubits: Qubit[], dataset:Bool[][]): Unit is Adj + Ctl{
        
    }
}