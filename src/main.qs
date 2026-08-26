namespace Main{
    operation GroverSearchAlgorithm(queries:(Int, Int, Int)[]): Result[]{
        use q = Qubit();
        let r = M(q);
        Reset(q);
        return [r];
    }

    operation BuildQROM(indexQubits: Qubit[], outputQubits: Qubit[], dataset:Bool[][]): Unit is Adj + Ctl{
        
    }
}