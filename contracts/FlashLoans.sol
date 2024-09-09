// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

// Uniswap interface and library imports
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IERC20.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/SafeERC20.sol";

contract FlashLoans {
    using SafeERC20 for IERC20;
    // Factory and Routing Addresses
    address private constant PANCAKE_FACTORY =
        0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address private constant PANCAKE_ROUTER =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;
    // Token Addresses
    address private constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant CROX = 0x2c094F5A7D1146BB93850f629501eB749f6Ed491;
    address private constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;

    uint256 private deadline = block.timestamp + 1 days;
    uint256 private constant MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;
    uint256 private constant addressZero =
        0x0000000000000000000000000000000000000000;

    function checkResult(
        uint repayAmount,
        uint acquireCoin
    ) private returns (bool) {
        return acquireCoin >= repayAmount;
    }
    function placeTrade(
        address fromToken,
        address toToken,
        uint amount
    ) private returns (uint) {
        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(
            frqomToken,
            toToken
        );
        require(
            conditional(address(pair) != addressZero),
            "FlashLoans: PAIR_NOT_EXIST"
        );
    }

    function initialArbitrage(address busdBorrow, uint amount) external {
        // For Safe unlimited approve for routerContract to spend
        IERC20(BUSD).safeApprove(address(PANCAKE_ROUTER), MAX_INT);
        IERC20(CROX).safeApprove(address(PANCAKE_ROUTER), MAX_INT);
        IERC20(CAKE).safeApprove(address(PANCAKE_ROUTER), MAX_INT);

        // Get pair
        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(
            busdBorrow,
            WBNB
        );
        require(
            conditional(address(pair) != addressZero),
            "FlashLoans: PAIR_NOT_EXIST"
        );
        // Get Tokens
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();
        // Get amounts
        uint amount0 = IUniswapV2Pair(pair).balanceOf(address(this));
        uint amount1 = IUniswapV2Pair(pair).balanceOf(address(this));
        // Get amounts out
        uint amount0out = busdBorrow == token0 ? amount : 0;
        uint amount1out = busdBorrow == token1 ? amount : 0;
        bytes memory data = abi.encodePacked(busdBorrow, amount, msg.sender);
        // Swap between pairs
        IUniswapV2Pair(pair).swap(
            amount0out,
            amount1out,
            address(this).address,
            data
        );
    }
    function pancakeCall(
        address _sender,
        uint _amount0,
        uint _amount1,
        bytes calldata _data
    ) external {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(
            token0,
            token1
        );
        require(msg.sender == pair, "FlashLoans: INSUFFICIENT_AMOUNT");
        require(_sender == address(this), "Sender does not match");

        (address busdBorrow, uint amount, address account) = abi.decode(
            _data,
            (address, uint, address)
        );

        uint fee = ((amount * 3) / 997) + 1;
        uint repayAmount = amount + fee;
        uint loanAmount = amount > 0 ? amount0 : amount1;

        uint trade1Coin = placeTrade(BUSD, CROX, loanAmount);
        uint trade2Coin = placeTrade(CROX, CAKE, loanAmount);
        uint trade3Coin = placeTrade(CAKE, BUSD, loanAmount);
        bool result = checkResult(repayAmount, trade3Coin);
        require(result, "FlashLoans: Arbitrage is not Profitable");

        IERC20(BUSD).transfer(account, trade3Coin - repayAmount);
        IERC20(busdBorrow).transfer(pair, repayAmount);
    }
}
