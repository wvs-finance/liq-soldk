beforeSwap -> processOptionSwap

function _processOptionSwap(address sender, PoolKey calldata key, bytes calldata hookData)
        internal
        returns (uint256 totalPremium)
    {
        OptionParams memory p = _decodeParams(hookData);
        // Get the strike, expiry, wether is call, contract size, maximum premium		
       
	    premiaPerContract = optionPrice (underlyingPrice, volatility, expiration)
		totalPremia =  premiaPerContract* contractSize
       
	   // currency0 = underlying (e.g. WETH), currency1 = quote token (e.g. USDC)
        address quoteToken = Currency.unwrap(key.currency1);
        address underlying = Currency.unwrap(key.currency0);
    
        uint256 fee = (totalPremium * protocolFeeBps) / 10_000;
	    
		                       /
		                      /
		  ---------------|-- /-------
		                 p* /
						   /
				----------		 
        
		LongPayout = contractSize *(price:: isCall ? currentPrice : strike)
		// NOTE: For either CALL/PUTS the collateral is the quoteToken, this is 
		// not correct since CALLS are COVERED (require collateral on underlying)
		// and PUTS are cash secured (require collateral on quoteToken)
		ShortCollateral = CollateralVault(quoteToken).availableLiquidity();
		//============================================
		---> INVARIANT::ShortCollateral > LongPayout <--------
		//============================================
	
        
		
		(seriesId, optionToken) = optionSeries.createSeries(
			underlying,
			quoteAsset,
			strike,
			exipiry,
			isCall			
		);
		
		
		
		
		--------------------------------------------------
        // Lock collateral in the vault so writers can't withdraw while options are live
        vault.lockCollateral(seriesId, quoteToken, LongPayout);

        // Mint option tokens to the trader (ERC20, transferable)
        optionSeries.mint(seriesId, sender, p.quantity);

        // Route premium: protocol fee stays in hook, remainder goes to vault as yield for LPs
        protocolFees[quoteToken] += fee;
        vault.receivePremium(quoteToken, totalPremium - fee);

        // Update protocol stats
        totalVolumeTraded += totalPremium;
        totalOpenInterest += p.quantity;

        emit OptionPurchased(sender, seriesId, p.quantity, totalPremium, vol);
        emit PriceQuoted(seriesId, spot, vol, unitPremium);
    }
