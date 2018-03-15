# Platform sale queue smartcontract

## Production compile

Please remove test functions from ./contracts/TokenSaleQueue.sol

```js
   //for test only
    function changeFinalTime(uint _finalTime) public onlyOwner {
        finalTime = _finalTime;
    }

    //for test only
    function getTokenRaised(address _tokenWallet) public view returns (uint256) {
        return tokenRaised[_tokenWallet];
    }
```

## Compile

```bash
npm i
npm run compile
```

## Test

```bash
truffle develop
test
```
