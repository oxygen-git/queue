var TokenSaleQueue = artifacts.require("./TokenSaleQueue.sol");
var ERC20 = artifacts.require("./ERC20.sol");


contract('TokenSaleQueue - Initial state', function(accounts) {
    it("owner it is the first account", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            return instance.getOwner.call();
        }).then(function(owner) {
            assert.equal(owner.valueOf(), accounts[0], "accounts[0] wasn't in the owner");
        });
    });

    it("manager it is the third account", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            return instance.getManager.call();
        }).then(function(manager) {
            assert.equal(manager.valueOf(),  accounts[1], "accounts[2] wasn't in the manager");
        });
    });

    it("recepient it is the second account", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            return instance.recepient.call();
        }).then(function(recepient) {
            assert.equal(recepient.valueOf(), accounts[2], "accounts[1] wasn't in the wallet");
        });
    });

    it("deadline it is the 5300000", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            return instance.deadline.call();
        }).then(function(deadline) {
            assert.equal(deadline.valueOf(), 5300000, "deadline wasn't not equal 5300000");
        });
    });

    it("extendedTime it is the 1000", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            return instance.extendedTime.call();
        }).then(function(extendedTime) {
            assert.equal(extendedTime.valueOf(), 1000, "extendedTime wasn't not equal 1000");
        });
    });

    it("maxTime it is the 5302000", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            return instance.maxTime.call();
        }).then(function(maxTime) {
            assert.equal(maxTime.valueOf(), 5302000, "maxTime wasn't not equal 5302000");
        });
    });

    it("finalTime it is the 5301000", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            return instance.finalTime.call();
        }).then(function(finalTime) {
            assert.equal(finalTime.valueOf(), 5301000, "finalTime wasn't not equal 5302000");
        });
    });
});


contract('TokenSaleQueue - User function - whitelist', function(accounts) {
    it("add users in whitelist not by manager", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            return instance.addAddressInWhitelist(accounts[7], {from: accounts[7]});
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'Only owner can call this function.'
                )});
    });

    it("add nonexistent users in whitelist by manager", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            return instance.addAddressInWhitelist(0x0, {from: accounts[1]});
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'Input parameter was equal 0x0.'
                )});
    });

    it("add users in whitelist", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            instance.addAddressInWhitelist(accounts[7], {from: accounts[1]});
            return instance.isInWhiteList(accounts[7]);
        }).then(function(result) {
            assert.equal(result.valueOf(), true, "address wasn't not add in whitelist");
        });
    });
});


contract('TokenSaleQueue - User function - deposit (part 1)', function(accounts) {
    it("call deposit function without msg.value", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            return instance.deposit({from: accounts[7], value: 0});
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'value was not equal 0.'
                )});
    });

    it("call deposit function by user not from whitelist", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            return instance.deposit({from: accounts[7], value: 10});
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'user not from whitelist.'
            )});
    });

    it("call deposit function by user from whitelist after finalTime", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            instance.addAddressInWhitelist(accounts[7], {from: accounts[1]});
            instance.changeFinalTime(0);
            return instance.deposit({from: accounts[7], value: 10});
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'call deposit function after finalTime.'
                )});
    });
});


contract('TokenSaleQueue - User function - deposit (part 2)', function(accounts) {
    it("call deposit function with authorized user", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            instance.addAddressInWhitelist(accounts[7], {from: accounts[1]});
            instance.deposit({from: accounts[7], value: 123456789});
            return instance.balanceOf(accounts[7]);
        }).then(function(balance) {
            assert.equal(balance.valueOf(), 123456789, "balance wasn't not equal value");
        });
    });
});


contract('TokenSaleQueue - User function - withdraw', function(accounts) {
    it("call withdraw function with balance 0", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            return instance.withdraw({from: accounts[6]});
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'after finalTime.'
                )});
    });

    it("call withdraw function", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            instance.addAddressInWhitelist(accounts[7], {from: accounts[1]});
            instance.deposit({from: accounts[7], value: 123456789});
            instance.withdraw({from: accounts[7]});
            return instance.balanceOf(accounts[7]);
        }).then(function(balance) {
            assert.equal(balance.valueOf(), 0, "balance in contract wasn't not equal 0");
        });
    });
});


contract('TokenSaleQueue - User function - authorize', function(accounts) {
    it("call authorize function by not manager", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            instance.addAddressInWhitelist(accounts[7], {from: accounts[1]});
            instance.deposit({from: accounts[7], value: 123456789});
            return instance.authorize(accounts[7], {from: accounts[5]});
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'not manager call onlyManager.'
                )});
    });

    it("call authorize function with input parameter 0", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            return instance.authorize(0x0, {from: accounts[1]});
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'input parameter is 0.'
                )});
    });

    it("call authorize function", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            instance.addAddressInWhitelist(accounts[6], {from: accounts[1]});
            instance.deposit({from: accounts[6], value: 123456789});
            instance.authorize(accounts[6], {from: accounts[1]});
            return instance.isAuthorized(accounts[6]);
        }).then(function(auth) {
            assert.equal(auth.valueOf(), true, "auth account in contract wasn't not equal true");
        });
    });
});


contract('TokenSaleQueue - User function - process', function(accounts) {
    it("call process function without auth", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            instance.addAddressInWhitelist(accounts[6], {from: accounts[1]});
            instance.deposit({from: accounts[6], value: 123456789});
            return instance.process({from: accounts[6]});
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'process without auth.'
                )});
    });

    it("call process function with balance 0", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            instance.addAddressInWhitelist(accounts[7], {from: accounts[1]});
            return instance.process({from: accounts[7]});
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'process with accounts with balance 0.'
                )});
    });

    it("call process function", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            instance.addAddressInWhitelist(accounts[5], {from: accounts[1]});
            instance.deposit({from: accounts[5], value: 123456789});
            instance.authorize(accounts[5], {from: accounts[1]});
            instance.process({from: accounts[5]});
            return instance.balanceOf(accounts[5]);
        }).then(function(balance) {
            assert.equal(balance.valueOf(), 0, "balance in contract wasn't not equal 0");
        });
    });
});


contract('TokenSaleQueue - Token function - tokenWalletsWhitelist', function(accounts) {
    it("add token in whitelist not by manager", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            return TSQinstance.addTokenWalletInWhitelist(ERC.address);
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'Only manager can call this function.'
                )});
    });

    it("add nonexistent token in whitelist by manager", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
                return instance.addTokenWalletInWhitelist(0x0, {from: accounts[1]});
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'Input parameter was equal 0x0.'
                )});
    });

    it("add token in whitelist", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            TSQinstance.addTokenWalletInWhitelist(ERC.address, {from: accounts[1]});
            return TSQinstance.tokenInWhiteList(ERC.address);
        }).then(function(result) {
            assert.equal(result.valueOf(), true, "address wasn't not add in whitelist");
        });
    });

    it("add token in whitelist second time", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            return TSQinstance.addTokenWalletInWhitelist(ERC.address, {from: accounts[1]});
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'Input parameter was add in map earlier.'
                )});
    });
});


contract('TokenSaleQueue - Token function - tokenDeposit (part 1)', function(accounts) {
    it("call tokenDeposit function with amount 0", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            return TSQinstance.tokenDeposit(ERC.address, 0);
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'amount was not equal 0.'
                )});
    });

    it("call tokenDeposit function by token not from whitelist", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            return TSQinstance.tokenDeposit(ERC.address, 10);
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'token not from whitelist.'
                )});
    });

    it("call tokenDeposit function by user not from whitelist", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            TSQinstance.addTokenWalletInWhitelist(ERC.address, {from: accounts[1]});
            return TSQinstance.tokenDeposit(ERC.address, 10);
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'user not from whitelist.'
                )});
    });
});

contract('TokenSaleQueue - Token function - tokenDeposit (part 2)', function(accounts) {
    it("call tokenDeposit function with authorized user after finalTime", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            TSQinstance.addTokenWalletInWhitelist(ERC.address, {from: accounts[1]});
            TSQinstance.addAddressInWhitelist(accounts[0], {from: accounts[1]});
            TSQinstance.changeFinalTime(0);
            return TSQinstance.tokenDeposit(ERC.address, 10);
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'after finalTime.'
                )});
    });
});

contract('TokenSaleQueue - Token function - tokenDeposit (part 3)', function(accounts) {
    it("call tokenDeposit function with authorized user before finalTime without approve tokens", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            TSQinstance.addTokenWalletInWhitelist(ERC.address, {from: accounts[1]});
            TSQinstance.addAddressInWhitelist(accounts[0], {from: accounts[1]});
            return TSQinstance.tokenDeposit(ERC.address, 10);
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'after finalTime.'
                )});
    });
});


contract('TokenSaleQueue - Token function - tokenDeposit (part 4)', function(accounts) {
    it("call tokenDeposit function with all requirements) ", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            TSQinstance.addTokenWalletInWhitelist(ERC.address, {from: accounts[1]});
            TSQinstance.addAddressInWhitelist(accounts[0], {from: accounts[1]});
            ERC.approve(TSQinstance.address, 10);
            TSQinstance.tokenDeposit(ERC.address, 10);
            return TSQinstance.tokenBalanceOf(ERC.address, accounts[0]);
        }).then(function(tokenBalance) {
            assert.equal(tokenBalance.valueOf(), 10, "balance wasn't not equal value");
        });
    });
});


contract('TokenSaleQueue - Token function - tokenWithdraw', function(accounts) {
    it("call tokenWithdraw function with token balance 0", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            return TSQinstance.tokenWithdraw(ERC.address, {from: accounts[6]});
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'token balance is not equal 0.'
                )});
    });

    it("call tokenWithdraw function", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            TSQinstance.addTokenWalletInWhitelist(ERC.address, {from: accounts[1]});
            TSQinstance.addAddressInWhitelist(accounts[0], {from: accounts[1]});
            ERC.approve(TSQinstance.address, 10);
            TSQinstance.tokenDeposit(ERC.address, 10);
            TSQinstance.tokenWithdraw(ERC.address);
            return TSQinstance.tokenBalanceOf(ERC.address, accounts[0]);
        }).then(function(tokenBalance) {
            assert.equal(tokenBalance.valueOf(), 0, "tokenBalance wasn't not equal 0");
        });
    });
});


contract('TokenSaleQueue - Token function - tokenProcess (part 1)', function(accounts) {
    it("call process function with balance 0", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            return TSQinstance.tokenProcess(ERC.address);
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'process with accounts with balance 0.'
                )});
    });

    it("call process function without auth", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            TSQinstance.addTokenWalletInWhitelist(ERC.address, {from: accounts[1]});
            TSQinstance.addAddressInWhitelist(accounts[0], {from: accounts[1]});
            ERC.approve(TSQinstance.address, 10);
            TSQinstance.tokenDeposit(ERC.address, 10);
            return TSQinstance.tokenProcess(ERC.address);
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'process without auth.'
                )});
    });
});

contract('TokenSaleQueue - Token function - tokenProcess (part 2)', function(accounts) {
    it("call process function", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            TSQinstance.addTokenWalletInWhitelist(ERC.address, {from: accounts[1]});
            TSQinstance.addAddressInWhitelist(accounts[0], {from: accounts[1]});
            ERC.approve(TSQinstance.address, 10);
            TSQinstance.tokenDeposit(ERC.address, 10);
            TSQinstance.authorize(accounts[0], {from: accounts[1]});
            TSQinstance.tokenProcess(ERC.address);
            return TSQinstance.tokenBalanceOf(ERC.address, accounts[0]);
        }).then(function(tokenBalance) {
            assert.equal(tokenBalance.valueOf(), 0, "token balance in contract wasn't not equal 0");
        });
    });
});


contract('TokenSaleQueue - Token function - reclaimTokens (part 1)', function(accounts) {
    it("call reclaimTokens function before finalTime", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            return TSQinstance.reclaimTokens([ERC.address]);
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'before finalTime.'
                )});
    });
});


contract('TokenSaleQueue - Token function - reclaimTokens (part 2)', function(accounts) {
    it("call reclaimTokens function", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            TSQinstance.addTokenWalletInWhitelist(ERC.address, {from: accounts[1]});
            TSQinstance.addAddressInWhitelist(accounts[0], {from: accounts[1]});
            ERC.approve(TSQinstance.address, 10);
            TSQinstance.tokenDeposit(ERC.address, 10);
            TSQinstance.authorize(accounts[0], {from: accounts[1]});
            TSQinstance.changeFinalTime(0);
            TSQinstance.reclaimTokens([ERC.address], {from: accounts[9]});
            return ERC.balanceOf(accounts[2]);
        }).then(function(balance) {
            assert.equal(balance.valueOf(), 10, "recepient balance in token wallet wasn't equal 0");
        });
    });
});


contract('TokenSaleQueue - changeExtendedTime', function(accounts) {
    it("call changeExtendedTime not by owner", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            return instance.changeExtendedTime(1000, {from: accounts[7]});
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'Only owner can call this function.'
                )});
    });

    it("call changeExtendedTime with big input parameter", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            return instance.changeExtendedTime(1000000000000);
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    '(deadline + extendedTime) > maxTime.'
                )});
    });

    it("call changeExtendedTime", function() {
        return TokenSaleQueue.deployed().then(function(instance) {
            instance.changeExtendedTime(10);
            return instance.finalTime.call();
        }).then(function(finalTime) {
            assert.equal(finalTime.valueOf(), 5300010, "finalTime wasn't equal 5300010");
        });
    });
});


contract('TokenSaleQueue - destroy', function(accounts) {
    it("call destroy function by not owner", function() {
        return TokenSaleQueue.deployed().then(function(TSQinstance) {
            return TSQinstance.destroy({from: accounts[5]});
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'not owner call refund function.'
                )});
    });

    it("call destroy function before finalTime", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            return TSQinstance.destroy();
        }).then(assert.fail)
            .catch(function(error) {
                assert.include(
                    error.message,
                    'VM Exception while processing transaction: revert',
                    'call refund function before finalTime.'
                )});
    });

    it("call destroy function before finalTime", function() {
        var ERC;

        return ERC20.deployed().then(function(ERCinstance) {
            ERC = ERCinstance;
            return TokenSaleQueue.deployed();
        }).then(function(TSQinstance) {
            TSQinstance.changeFinalTime(0);
            TSQinstance.destroy();
        });
    });
});