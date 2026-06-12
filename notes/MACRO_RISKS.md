  The Reality Check                                                                                                                                                                     
  Macro Risk Proxies Beyond Pure FX                                                                                                                                                     
                                         
  For underserved countries, FX depreciation is often the dominant macro risk 
  ---> It proxies GDP decline, inflation, capital flight). But you can go further:                              
                                                                     
MacroRisk {
	LocalInflation       -->    AMP/other currrency , PAXG/ , WBTC , 
	InterestRateShock    -->    stETH yield vs. local stablecoin yield spread
	TermsOfTrade         -->    RWACommodityToken / local stable coin
	CapitalFlight        -->    LocalStableCoint/ cUSD implied vol
	RemittanceCorridorRisk -->  CrossStableCoin spreads
}


LocalInflation{
	Attemps: [
		{
			usa,
			1985,
			CPI index futures
		},
		
		{
			Brazil,
			1987
			CPI index futures
		}
	]

}

d Flow = deterministic + (random -> hedgeable)

   | 
    --> d _{lags}     ease of observable measurement
	   d_{inmediate} (e.g fire of a house) -> easier to observe -> easier to ensure

Macro(FinancialContract){
     settlement(MacroRisk, measure (input))
	                             |
                                  ----> exisiting difficulty
								              |
                                            (Theory of Index Numbers)
 }


TradingVolume (Agg (local / host (migrant country)){
      Corridor-weighted basket as HOST-country	---> labor demand 
	  d TVOLUME / DT --> host recession hitting local migrant workers
}

ExchangeRate (local /host ){
     Spread (onChain, centralBank (via chainlink)) --> capital controls, currency crisis, macro stress

      Perpetual claim on the cNGN/USDC implied depreciation rate

       Index = rolling 30d VWAP of cNGN/USDC across Mento + Uniswap
           vs. CBN official rate (via Chainlink or custom oracle)

        Premium = f(realized vol of the spread) 
        Index = rolling 30d VWAP of cNGN/USDC across Mento + Uniswap
           vs. CBN official rate (via Chainlink or custom oracle)
}



### Pension Funds

- Employer contributions to pension funds could be debited and credited representing the employee's gains or losses in macro markets

### Labor Unions
- use these markets to help protect their members against adverse labor market conditions 
  --> transference of risks that individual workers face to the financial markets, by loading the risk 
    d risk(W) ---> d price (firm) ---> Held in diversified portafolios


#### **Challenge**
	- not(perpetual (laborContracts)) ^ perpetual(worker hedging intertests) ->

#### **Solution**
	 - employer ----> hedge(random (d W / d I)) ---> employee
	                           
                               |
							   |
							   v
					          d W  --> not fixed salary		   


# Psychology --> Approaching the Public


risk management ----(attracteiveness) ----> insurance
x							                   |
                                               |
                                               v
											 losses market


frame:: income

-  no risk averse on gains market 
    -> (   [100%,- 3000]      ,    [80% , -4000])
                 |                      |
                 V                      v
         E [" "] = 3000     <        E[" "] = -3200  (X)

- risk averse on loss market 
   -> (    [100% , 3000]      ,      [80% , 4000 ])
                 
                 |                       |
 				 V                       v
		 E [" "] = 3000 [X]	             E[" "] = 3200
                  
frame :: wealth optimal is the reverse



- informational cascades
- gambling behavio{
	- risk-taking behavior
	- play a game that is attractive to them (mastery of the game dominate chance)
}


- adoption --> public education --> retail firms -------nexus (context)--->  social-psycological effects
                                                             |
                                                             |
		insurance best offered framed as/on part of contract negotioation rather than  offered by insurance salesman
		
- IMPORTANT (COMPOSABILITY): combination with other risk-management products that already won accpentance

frame risk as eliminatign rather than reducing, adn eliminating a "borader" trather than a specific



```
FinancialContract {

    // Layer 1: What we WANT to hedge
    Claim :: Flow(Forward(Income, futureTime))
    
    // Layer 2: What we CAN observe
    Settlement {
        
        // The market itself IS the oracle
        oracle :: CashMarket {
            // The cash market produces a price by aggregating
            // private information from participants with skin in the game
            mechanism :: Aggregator(Expectations, Information, Incentive)
            
            // What the market actually trades
            underlying :: PerpetualClaim(Index(Income))
        }
        
	   // note: Removes the noise from the signal/index such that it reflects the value
        // wnated to be tracked and it DOES reduce risk not introdouce it du to thje noise fo the signla
		
		/// 
		observable :: controlled(process(oracle(observables)))) :: Series<Signal>
		
		// build / construccted to reflect the Claim best observable proxy
		::Index 
  		// The actual payout computation
        payoff :: f(observable.price, strike, direction)
    }

    // Layer 3: The gap between claim and settlement
    BasisRisk :: Distance(Claim, Settlement.oracle.underlying)
    // i.e., how far is the traded index from actual income?
}

PerpetualFutures :: CashMarket {
    
    observables :: {
        mark_price    :: continuous, manipulation-resistant
        funding_rate  :: 8h signal encoding directional consensus
        open_interest :: total capital committed to views
        basis         :: spread(perp_price, spot_price)
        liquidations  :: forced unwinds = stress signal
    }
    
    // The funding rate IS Shiller's "incentivized information revelation"
    // Traders pay to hold their view → they only hold if they believe it
    funding_rate :: Transfer(longs, shorts) | Transfer(shorts, longs)
    // positive funding = market is net long = consensus expects price UP
    // negative funding = market is net short = consensus expects price DOWN
``` 



## Settlement


```
PRICE-SETTLED CLAIMS                 INCOME-SETTLED CLAIMS
─────────────────────                ─────────────────────
Observable: market price             Observable: accrued revenue
Updates: every trade                 Updates: every block
Source: exchange/pool                Source: protocol accounting
                                     
Measures: expectations               Measures: ACTUAL REALIZED VALUE
          (forward-looking)                    (backward-looking)

Noise: speculation, manipulation,    Noise: MEV, protocol upgrades,
       liquidity artifacts                  reward schedule changes

Settlement: f(price_t - strike)      Settlement: f(income_t - strike)
```

| Dimension | Price Settlement | Income Settlement |
|---|---|---|
| **What it measures** | Market expectations (forward) | Realized value (backward) |
| **Manipulation surface** | Flash loans, wash trading, oracle attacks | Harder — income accrues over time, not in a single tx |
| **Basis risk** | High — price may diverge from fundamentals | Low — income IS the fundamental |
| **Liquidity requirement** | Needs deep cash market for clean prices | Needs none — reads protocol state directly |
| **Latency** | Real-time (every trade) | Real-time (every block) |
| **Hedging utility** | Hedges against price movements | Hedges against income decline |
| **Speculation** | Easy — just trade the underlying | Harder — how do you short someone's yield? |
| **Bootstrapping** | Chicken-and-egg (need liquidity for prices) | No bootstrapping needed — income exists already |
| **Composability** | Universal — any ERC-20 has a price | Protocol-specific — must understand each income source |
| **Standardization** | High — price is price | Low — income means different things per protocol |



### Income

- eliminates liquidity bootstrapping problem
```
On-Chain Income Observables {

    // Protocol-level income (accrues to LPs/stakers)
    LP_Fee_Revenue {
        source    :: pool.feeGrowthGlobal{0,1}    // Uniswap v3
        granularity :: per-tick, per-position, per-block
        queryable :: yes, fully on-chain
        example   :: "USDC fees earned by cNGN/USDC LPs in epoch t"
    }
	   ....
}
```


```
Income Claims Spanning Space {

    // 1. INCOME FLOOR (put on income stream)
    // "Pay me if my LP fee revenue drops below X"
    IncomeFloor {
        underlying :: cumulative_fees(pool, epoch)
        strike     :: minimum_acceptable_income
        payoff     :: max(0, strike - realized_income)
        analog     :: interest rate floor
    }
    
    // 2. INCOME SWAP (exchange variable for fixed)
    // "I give you my variable LP fees, you give me fixed rate"
    IncomeSwap {
        leg_A :: realized_fees(pool, epoch)       // variable
        leg_B :: fixed_rate × notional             // fixed
        payoff :: leg_B - leg_A  (for fixed receiver)
        analog :: interest rate swap
    }
    
    // 3. INCOME CAP (call on income stream)
    // "Pay me the excess if fees exceed X" 
    // (useful for protocol treasuries capping LP rewards)
    IncomeCap {
        underlying :: cumulative_fees(pool, epoch)
        strike     :: cap_level
        payoff     :: max(0, realized_income - strike)
        analog     :: interest rate cap
    }
    
    // 4. RELATIVE INCOME (cross-protocol spread)
    // "Pay me if Aave USDC yield drops below Compound USDC yield"
    RelativeIncome {
        underlying :: income_A - income_B
        strike     :: spread_threshold
        payoff     :: f(spread vs. threshold)
        analog     :: basis swap
    }
    
    // 5. INCOME SWAPTION (option to enter income swap)
    // "Give me the right to lock in fixed income next epoch"
    IncomeSwaption {
        underlying :: IncomeSwap(future_epoch)
        strike     :: fixed_rate
        payoff     :: optionality on the swap
        analog     :: swaption
    }
    
    // 6. INCOME PERPETUAL (Shiller's construct, directly)
    // Perpetual claim on rolling income stream
    IncomePerpetual {
        underlying :: rolling_income(pool, trailing_30d)
        funding    :: income_realized vs. income_expected
        payoff     :: continuous mark-to-market
        analog     :: Shiller's perpetual income claim
    }
    
    // 7. CROSS-COUNTRY INCOME SPREAD
    // "Pay me if Nigerian LP income falls relative to 
    //  Philippine LP income" (macro relative value)
    CrossCountrySpread {
        underlying :: income(cNGN_pools) / income(PUSO_pools)
        strike     :: ratio_threshold
        payoff     :: f(ratio vs. threshold)
        analog     :: macro relative value trade
    }
}
```

#### **Claim Flows**

```
Flow 1: MARK-TO-MARKET (price convergence) --> correction
        Purpose: keep derivative price = fair value
		Direction: alternates (longs↔shorts based on mispricing) 
		
		PERP-FUTURES {
		
			 funding_rate (every 8h)
                    = (perp_price - index_price) × position_size
                    Direction: overpriced side pays underpriced side
		}
		
		CFMM {
			Arbitrageurs
                    When index price moves, arbs trade the pool 
                    to correct the price
                    LPs "pay" via impermanent loss
                    Arbs "receive" the profit
		
		}
        
Flow 2: DIVIDEND (income distribution)  --> payment for bearing risk
        Purpose: transfer the actual income to claim holders
        Direction: always shorts → longs
        (shorts are "renting out" their side of the income stream)
		
		
		PERP-FUTURES {
		            NOT NATIVELY SUPPORTED
                    Standard perps have no dividend mechanism
                    
                    To add it, you modify the funding rate:
                    
                    total_funding = convergence_funding + dividend_funding
                    
                    convergence = (perp_price - spot) / 8h
                    dividend    = index_income_accrued / 8h
                    
                    Shorts always pay the dividend component
                    Convergence component alternates as usual

		}
		
		CFMM  {
			Dividend:           
			               Fee accrual
			               Every swap pays a fee to LPs
	                       This fee IS an income stream
		
		}

#### **ClaimFlows<CFMM>**

```
Shiller's Construct          CFMM Realization
───────────────────          ────────────────────

LONG the income claim   ←→   LP position
(receives dividend)          (receives fee revenue)

SHORT the income claim  ←→   Swap traders / arbitrageurs  
(pays dividend)              (pay fees on every trade)

Mark-to-market          ←→   Arbitrage  
(price convergence)          (corrects pool price to oracle)

Dividend payment        ←→   Trading fees
(income transfer)            (flow from traders to LPs)
```


invariants:
	SOLVENCY:: NET VALUE OF ALL POSITIONS IS ZERO 


- From a adaptive fee that upadtes on volaitility, feeRevenue is a volatiltiy oracle and also income
since LP's are SHORT volatility. THen LONG volatility is taken by making the dynamic fee react to volatility. Then TRADERS end up being SHORT volatility


```
Standard CFMM:

LP receives:  +fees (dividend)
LP pays:      -impermanent_loss (mark-to-market cost)

Net LP income = fees - IL

These two flows are NOT separated.
They happen simultaneously, to the same party.
```

In Shiller's construct, the long receives dividends AND benefits from mark-to-market when the index rises. In a CFMM, the LP receives fees BUT suffers IL when price moves. The flows are **inversely structured** — the LP's mark-to-market goes the wrong way.

## The Reconciliation

```
                     Mark-to-Market    Dividend
                     (who benefits     (who receives
                      from price       income)
                      convergence)

Shiller Long         ✓ benefits        ✓ receives
Shiller Short        ✗ pays            ✗ pays

CFMM LP              ✗ pays (IL)       ✓ receives (fees)
CFMM Trader          ✓ benefits (arb)  ✗ pays (fees)

Perp Long            ✓/✗ (alternates)  ✓ receives (if modified)
Perp Short           ✗/✓ (alternates)  ✗ pays (if modified)
```

## For Your Income Perpetual on a CFMM

To build Shiller's perpetual income claim on top of a CFMM, you need to **decompose the LP position** into its two components:

```
LP_Position = Income_Component + Price_Component

Income_Component (Shiller's dividend):
    = cumulative_fees_earned(t)
    Observable: feeGrowthGlobal, feeGrowthInside
    Always positive, always flows to LP
    THIS is what your income perpetual settles against

Price_Component (mark-to-market):
    = impermanent_loss(t)  
    Observable: position value vs. HODL value
    Can be positive or negative
    THIS is what Panoptic options already handle
```

The income perpetual claim would:

1. **Longs** receive a funding payment = realized fee income per unit of index per period
2. **Shorts** pay that funding payment
3. **Separately**, mark-to-market adjusts based on the market's expectation of future fee income

```
IncomePerpetual(cNGN_USDC_pool) {

    index_value :: cumulative_fee_revenue(pool, trailing_30d)
    
    // Dividend: realized income distribution
    dividend(t) :: fee_revenue(t-1, t) / total_long_notional
    direction   :: always shorts → longs
    frequency   :: every epoch (could be every block on-chain)
    
    // Mark-to-market: expectation adjustment  
    mark_to_market(t) :: (market_price - fair_value) × rate
    direction         :: overpriced side → underpriced side
    frequency         :: continuous (via funding rate)
    
    // Fair value of the perpetual claim
    fair_value :: Σ(expected_future_dividends) / discount_rate
    // This IS the "cash market price" Shiller describes
}
```

The beautiful thing is that on-chain, `fee_revenue(t-1, t)` is not estimated or reported — it's **exactly computable** from `feeGrowthGlobal`. The dividend is a mathematical fact, not an accounting opinion.



## Price


### controlled(oracle(observables))) Settlement :: Iliquid(CashMarket)


REASONS {
	Iliquid(CashMarket)
	HETEROGENITY (CashMarket)
}


Objective :: **eliminating quality/composition noise from the settlement price**.
Solution:: {
	HIGH (LIQUIDITY) 
	METHODS: PERPETUALS	
}
```

### Pipeline(controlled(oracle(observables))) Settlement :: Iliquid(CashMarket) && :: Index )

```
Phase 1: SIGNAL PROCESSING (information theory)
┌─────────────────────────────────────────────┐
│                                             │
│  Raw Observable     →  Filter  →  Signal    │
│                                             │
│  funding_rate(raw)  →  TWAP    →  funding   │
│                        EMA        signal    │
│                        Kalman               │
│                        outlier              │
│                        removal              │
│                                             │
│  spot_price(raw)    →  TWAP    →  price     │
│                        median     signal    │
│                                             │
│  volume(raw)        →  normalize→ flow      │
│                        deseason   signal    │
│                                             │
│  Theory: Shannon, Wiener, Kalman            │
│  Question: what is the TRUE state?          │
│  Error: noise, distortion, latency          │
└─────────────────────────────────────────────┘
                      │
                      ▼
Phase 2: INDEX CONSTRUCTION (measurement theory)
┌─────────────────────────────────────────────┐
│                                             │
│  Signals     →  Methodology  →  Index       │
│                                             │
│  funding_signal ─┐                          │
│  price_signal   ─┼→  aggregate  →  macro    │
│  flow_signal    ─┘    weight       stress   │
│                       normalize    index    │
│                                             │
│  Theory: Laspeyres, Paasche, Fisher         │
│  Question: what REPRESENTS the concept?     │
│  Error: methodology bias, proxy distance    │
└─────────────────────────────────────────────┘
                      │
                      ▼
Phase 3: SETTLEMENT (contract theory)
┌─────────────────────────────────────────────┐
│                                             │
│  Index  →  payoff function  →  settlement   │
│                                             │
│  macro_stress_index(t)                      │
│    vs. strike_value                         │
│    = cash_payout                            │
│                                             │
│  Theory: derivatives pricing, Shiller       │
│  Question: what do we PAY?                  │
│  Error: basis risk (index ≠ actual income)  │
└─────────────────────────────────────────────┘
```





