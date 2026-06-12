



## DESIRED MEANS ( TOOLING )

- Use Lean4 heavily 
- Express problems as convex optimization prblmes
- Numerical optimizatoipn, Apporximation
- Compariative statics
- Dynamic General Equilibria


forge test  --mt test_Success_mintOptions_ITMShortPutShortCall_Swap  
--fork-url 
                                                                                                         
export RCP="https://eth-mainnet.g.alchemy.com/v2/fd_m2oikp78msnnQGxO6H" && 
export DEFAULT_BLOCK_NUMBER=18963715 &&
source /home/jmsbpp/.bashrc && 

forge test --mt test_Success_mintOptions_ITMShortPutShortCall_Swap --fork-url "https://eth-mainnet.g.alchemy.com/v2/fd_m2oikp78msnnQGxO6H"  --fork-block-number 18963715 --json --summary --detailed --flamechart -vvvv > out.txt

