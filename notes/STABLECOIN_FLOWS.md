

# StableCoin Flows
## [Estimate International Stablecoin Flows](../refs/macro-risk/imf-estimating-stablecoin-flows-2025.pdf)


LATAM{
	- USAGE {
        WHEN:
	       - DIFFICULTY/ TX cost on traditional channels
        CASES: [
			REMITTANCES
		]
	}
	- CEX = BINANCE
	
	- UNIT_OF_MEASUREMENT = [ USDT, DAI, AMPL, ...]
	
	- UNDERLYING = [COP, ARG, MXN, ...]
    
	- MARKETS : UNDERLYING -> UNIT_OF_MEASURMENT
	
	- INTERSET : UNDERLYING -> TIME 
	- EXTERNAL_INTEREST : UNIT_OF_MEASURMENT -> TIME

    - Significance(relative=GDP) :: HIGH
	
	CoveredInterestParity:: {
		rateOfCahnge(inflow) >0
	}
	
	Depreciation :: Diff(ExchangeRate) {
		rateOfChange(inflow) > 0 ~ 5%
	}
	Outflow ::VolumeFlow(origin = US){
			rateOfChange(INFLATION(Currency(LATAM))) > 0 "Strong US Dollar => outflow"
		}
	}
	
	Inflow:: VolumeFlow(destination = USS){
		
		CoMovements [
			parityDeviation
		]
	}
	
}	
## [Stablecoin Inflows --(side effects)---> FX Markets](../refs/macro-risk/imf-stablecoin-spillovers-fx-2026.pdf)

	ParityDeviation::cost(stableCoin) - cost(FXCurrency) {
	       rateOfChange(inflow) > 0 ~ 40%
		   CoMovements [
			   Inflow;
			   Depreciation			   
		   ]
		   co-move (Inflow)
		   
	}
	
	
}
}	
 
 Net Flows vs NAr,t = β1 VIXt + β2 sum(USD/OTHER CURRENCIES) + β3 Setiment + αr,Q + Weekend + ϵr,t

- ESTIMATION OF ORIGN OF ADDRESES [
  DATASETS: CHAINANALYSYS
]
### Insights
The 18 March 2023 banking crisis --> THIS CAN BE HEDGE OR ESTIMATED UYSIGN DAI, AMPL against the centralizedd currencies


## [Stablecoin Inflows --(side effects)---> FX Markets](../refs/macro-risk/imf-stablecoin-spillovers-fx-2026.pdf)



parrityDeviation::cost(stableCoin) - cost(FXCurrency) {
	rateOfChange(exchangeRate)
}

- SI-FX::InstrumentalVariable :: Inflows(Volume(StableCoin)) -> FX Markets
  - '''idiosyncratic shocks to stablecoin net inflows in other currencies'''
   
   FXMarket {
	   rateOfChange(
                     diff(
					      exchangeRate(FXMarket),
						  exhangeRate(StableCoinMarket)
					  ),
						  Inflows(Volume(StableCoin))
						  ) > 0
   }
   
   Inflows_i(StablecoinUSD) {

		Δ parityDeviation_i      > 0      (≈ +40 bps per +1%)
		Δ FX_rate_i              < 0      (local currency depreciates)
		Δ CIP_basis_i            > 0      (dollar premium widens)
}

- side effects  GROW disproportionally when intermediaries (banks backing reserves) suffer losses

