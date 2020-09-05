const assert = require('assert');
const BigNumber = require('bignumber.js');

const log = (...message) => {
    console.log("  [TEST] >>", ...message);
};

const _weis = new BigNumber('1000000000000000000');

const toWei = (...xs) => {
    let sum = new BigNumber(0);
    for (var x of xs) {
        sum = sum.plus(new BigNumber(x).times(_weis));
    }
    return sum.toFixed();
};

const fromWei = x => {
    return new BigNumber(x).div(_weis).toString();
};

const _wad = new BigNumber('1000000000000000000');

const toWad = (...xs) => {
    let sum = new BigNumber(0);
    for (var x of xs) {
        sum = sum.plus(new BigNumber(x).times(_wad));
    }
    return sum.toFixed();
};

const fromWad = (x, prec = 18) => {
    return new BigNumber(x).div(_wad).toFixed(prec);
};

const infinity = '999999999999999999999999999999999999999999';

const Side = {
    FLAT: 0,
    SHORT: 1,
    LONG: 2,
}

const addLeadingZero = (str, length) => {
    let len = str.length;
    return '0'.repeat(length - len) + str;
};

const uintToBytes32 = u => {
    return "0x" + addLeadingZero(new BigNumber(u).toString(16), 64);
}

const toBytes32 = s => {
    return web3.utils.fromAscii(s);
};

const fromBytes32 = b => {
    return web3.utils.toAscii(b);
};

const clone = x => JSON.parse(JSON.stringify(x));

const shouldFailOnError = async (message, func) => {
    try {
        await func();
    } catch (error) {
        assert.ok(
            error.message.includes(message),
            `exception should include "${message}", but get "${error.message}"`);
        return;
    }
    assert.fail(`should fail with "${message}"`);
};

const call = async (user, method) => {
    return await method.call();
};

const send = async (user, method, gasLimit = 8000000) => {
    return await method.send({ from: user, gasLimit: gasLimit });
};

const initializeToken = async (token, admin, balances) => {
    for (let i = 0; i < balances.length; i++) {
        const to = balances[i][0];
        const amount = toWad(balances[i][1]);
        await send(token.methods.mint(to, amount), admin);
    }
};

function createEVMSnapshot() {
    const id = Date.now() + Math.floor(Math.random() * 100000000);
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'evm_snapshot',
            params: [],
            id: id,
        }, (err, resp) => {
            if (err) {
                reject(err);
                return;
            }
            resolve(resp.result);
        });
    });
}

function restoreEVMSnapshot(snapshotId) {
    const id = Date.now() + Math.floor(Math.random() * 100000000);
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'evm_revert',
            params: [snapshotId],
            id: id,
        }, (err, resp) => {
            if (err) {
                reject(err);
                return;
            }
            if (resp.result !== true) {
                reject(resp);
                return;
            }
            resolve();
        });
    });
}

function increaseEvmTime(duration) {
    const id = Date.now() + Math.floor(Math.random() * 100000000);
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'evm_increaseTime',
            params: [duration],
            id: id,
        }, (err, resp) => {
            if (err) {
                reject(err);
                return;
            }
            web3.currentProvider.send({
                jsonrpc: '2.0',
                method: 'evm_mine',
                params: [],
                id: id + 1,
            }, (err, resp) => {
                if (err) {
                    reject(err);
                    return;
                }
                resolve();
            });
        });
    });
}

function increaseEvmBlock(_web3) {
    if (typeof _web3 === 'undefined') {
        _web3 = web3;
    }
    const id = Date.now() + Math.floor(Math.random() * 100000000);
    return new Promise((resolve, reject) => {
        _web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'evm_mine',
            params: [],
            id: id,
        }, (err, resp) => {
            if (err) {
                reject(err);
                return;
            }
            resolve();
        });
    });
}

function stopMiner() {
    const id = Date.now() + Math.floor(Math.random() * 100000000);
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'miner_stop',
            params: [],
            id: id,
        }, (err, resp) => {
            if (err) {
                reject(err);
                return;
            }
            resolve();
        });
    });
}

function startMiner() {
    const id = Date.now() + Math.floor(Math.random() * 100000000);
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: '2.0',
            method: 'miner_start',
            params: [],
            id: id,
        }, (err, resp) => {
            if (err) {
                reject(err);
                return;
            }
            resolve();
        });
    });
}

function assertApproximate(assert, actual, expected, limit) {
    if (typeof limit === 'undefined') {
        limit = new BigNumber("1e-12");
    }
    actual = new BigNumber(actual);
    expected = new BigNumber(expected);
    const abs = actual.minus(expected).abs();
    if (abs.gt(limit)) {
        assert.fail(actual.toString(), expected.toString());
    }
}

const approximatelyEqual = (a, b, epsilon = 1000) => {
    var _a = new BigNumber(a);
    var _b = new BigNumber(b);
    return _a.minus(_b).abs().toFixed() <= epsilon;
}

const checkEtherBalance = async (doSomething, account, balanceDelta) => {
    var prev = new BigNumber(await web3.eth.getBalance(account));
    // console.log(prev.toFixed());
    var receipt = await doSomething;
    var tx = await web3.eth.getTransaction(receipt.receipt.transactionHash);
    var gas = new BigNumber(receipt.receipt.cumulativeGasUsed).times(new BigNumber(tx.gasPrice));
    var value = new BigNumber(tx.value);
    var post = new BigNumber(await web3.eth.getBalance(account));
    // console.log(post.toFixed());
    assert.equal(prev.minus(post).minus(gas).minus(value).toFixed(), balanceDelta);
}

const checkEtherBalanceNoGas = async (doSomething, account, balanceDelta) => {
    var prev = new BigNumber(await web3.eth.getBalance(account));
    // console.log(prev.toFixed());
    var receipt = await doSomething;
    var post = new BigNumber(await web3.eth.getBalance(account));
    // console.log(post.toFixed());
    assert.equal(prev.minus(post).toFixed(), balanceDelta);
}

function sleep(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

const inspect = async (user, perpetual, proxy, amm) => {
    const markPrice = await amm.currentMarkPrice.call();
    const cash = await perpetual.getCashBalance(user);
    const position = await perpetual.getPosition(user);
    console.log("  ACCOUNT STATISTIC for", user);
    console.log("  markPrice", fromWad(markPrice));
    console.log("  ┌─────────────────────────┬────────────");
    console.log("  │ COLLATERAL              │");
    console.log("  │   cashBalance           │", fromWad(cash.balance));
    console.log("  │   appliedWithdrawal     │", fromWad(cash.appliedBalance));
    console.log("  │ POSITION                │");
    console.log("  │   side                  │", position.side == Side.LONG ? "LONG" : (position.side == Side.SHORT ? "SHORT" : "FLAT"));
    console.log("  │   size                  │", fromWad(position.size));
    console.log("  │   entryValue            │", fromWad(position.entryValue));
    console.log("  │   entrySocialLoss       │", fromWad(position.entrySocialLoss));
    console.log("  │   entryFundingLoss      │", fromWad(position.entryFundingLoss));
    console.log("  │ Computed                │");
    console.log("  │   positionMargin        │", fromWad(await perpetual.positionMargin.call(user)));
    console.log("  │   marginBalance         │", fromWad(await perpetual.marginBalance.call(user)));
    console.log("  │   maintenanceMargin     │", fromWad(await perpetual.maintenanceMargin.call(user)));
    console.log("  │   pnl                   │", fromWad(await perpetual.pnl.call(user)));
    console.log("  │   drawableBalance       │", fromWad(await perpetual.drawableBalance.call(user)));
    console.log("  │   availableMargin       │", fromWad(await perpetual.availableMargin.call(user)));
    if (user === proxy.address) {
        console.log("  │   availableMargin(Pool) │", fromWad(await amm.currentAvailableMargin.call()));
    }
    console.log("  │   isSafe                │", await perpetual.isSafe.call(user));
    console.log("  │   isBankrupt            │", await perpetual.isBankrupt.call(user));
    console.log("  │ Broker                  │");
    console.log("  │   broker                │", (await perpetual.getBroker(user)).current.broker);
    console.log("  │   height                │", (await perpetual.getBroker(user)).current.appliedHeight);
    console.log("  └─────────────────────────┴────────────");
    console.log("");
};

const printFunding = async (amm, perpetual) => {
    const fundingState = await amm.currentFundingState.call();
    console.log(" FUNDING");
    console.log("  ┌───────────────────────────────┬────────────");
    console.log("  │ lastFundingTime               │", fundingState.lastFundingTime.toString());
    console.log("  │ lastPremium                   │", fromWad(fundingState.lastPremium));
    console.log("  │ lastEMAPremium                │", fromWad(fundingState.lastEMAPremium));
    console.log("  │ lastIndexPrice                │", fromWad(fundingState.lastIndexPrice));
    console.log("  │ accumulatedFundingPerContract │", fromWad(fundingState.accumulatedFundingPerContract));
    console.log("  │ fairPrice                     │", fromWad(await amm.currentFairPrice.call()));
    console.log("  │ premiumRate                   │", fromWad(await amm.currentPremiumRate.call()));
    console.log("  │ fundingRate                   │", fromWad(await amm.currentFundingRate.call()));
    console.log("  │ perp.totalSize                │", fromWad(await perpetual.totalSize(1)));
    console.log("  └───────────────────────────────┴────────────");
    console.log("");
};

const shouldThrows = async (fn, msg) => {
    try {
        await fn;
        throw new AssertionError("should throw expected msg but actually not");
    } catch (e) {
        assert.ok(e.message.includes(msg), "expect: [ " + msg + " ], got: [ " + e.message + " ]");
    }
};

module.exports = {
    log,
    toBytes32,
    fromBytes32,
    clone,
    shouldFailOnError,
    call,
    send,
    initializeToken,
    createEVMSnapshot,
    restoreEVMSnapshot,
    increaseEvmTime,
    increaseEvmBlock,
    stopMiner,
    startMiner,
    assertApproximate,
    sleep,
    inspect,
    printFunding,
    toWei,
    fromWei,
    toWad,
    fromWad,
    infinity,
    Side,
    shouldThrows,
    uintToBytes32,
    approximatelyEqual,
    checkEtherBalance,
    checkEtherBalanceNoGas,
};