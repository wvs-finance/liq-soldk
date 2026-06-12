

 
// we need a typed way to let tle LP define striotly whih is the undelrying and whihc asset is cahs


such that when interacting with the oracles and other API's the arg is not a raw address but the fucntion argument already embeds tehe fact that we are querying for the underlying


function from (Pair) {
    // note: safe, becuase function (address) needs validation against address(0x00) malicios tokens invalid tokens
    -> address  underlyint = underlying(pair)
    -> address uoa =  unitOfAccount(pair)
									}
