// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.6;

// Import necessary Uniswap interfaces and libraries
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router01.sol";
import "./interfaces/IUniswapV2Router02.sol";
import "./interfaces/IERC20.sol";
import "./libraries/UniswapV2Library.sol";
import "./libraries/SafeERC20.sol";

contract FlashLoan {
    using SafeERC20 for IERC20;

    // Define the PancakeSwap Factory and Router contract addresses for token swapping and liquidity operations
    address private constant PANCAKE_FACTORY =
        0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73;
    address private constant PANCAKE_ROUTER =
        0x10ED43C718714eb63d5aA57B78B54704E256024E;

    // Define commonly used token contract addresses (BUSD, WBNB, CROX, CAKE)
    address private constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address private constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address private constant CROX = 0x2c094F5A7D1146BB93850f629501eB749f6Ed491;
    address private constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;

    // Set transaction deadline to 1 day from the current block timestamp
    uint256 private deadline = block.timestamp + 1 days;

    // Define the maximum possible uint256 value
    uint256 private constant MAX_INT =
        115792089237316195423570985008687907853269984665640564039457584007913129639935;

    // Function to compare repayment amount with acquired amount to ensure profitability
    function checkResult(
        uint _repayAmount,
        uint _acquiredCoin
    ) private pure returns (bool) {
        return _acquiredCoin > _repayAmount;
    }

    // Function to get the current balance of a specific token held by the contract
    function getBalanceOfToken(address _address) public view returns (uint256) {
        return IERC20(_address).balanceOf(address(this));
    }

    // Execute a token swap between two tokens using the Uniswap Router, ensuring the output amount meets the expected amount
    function placeTrade(
        address _fromToken,
        address _toToken,
        uint _amountIn
    ) private returns (uint) {
        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(
            _fromToken,
            _toToken
        );
        require(pair != address(0), "Pool does not exist"); // Ensure liquidity pool exists

        // Create a token swap path
        address;
        path[0] = _fromToken;
        path[1] = _toToken;

        // Calculate the expected amount of tokens to receive
        uint256 amountRequired = IUniswapV2Router01(PANCAKE_ROUTER)
            .getAmountsOut(_amountIn, path)[1];

        // Perform the token swap and return the received token amount
        uint256 amountReceived = IUniswapV2Router01(PANCAKE_ROUTER)
            .swapExactTokensForTokens(
                _amountIn,
                amountRequired,
                path,
                address(this),
                deadline
            )[1];

        require(amountReceived > 0, "Transaction Abort"); // Ensure a successful trade

        return amountReceived;
    }

    // Initiate the flash loan and arbitrage process by borrowing a specific amount of BUSD from the liquidity pool
    function initateArbitrage(address _busdBorrow, uint _amount) external {
        // Approve the PancakeRouter to spend necessary tokens
        IERC20(BUSD).safeApprove(address(PANCAKE_ROUTER), MAX_INT);
        IERC20(CROX).safeApprove(address(PANCAKE_ROUTER), MAX_INT);
        IERC20(CAKE).safeApprove(address(PANCAKE_ROUTER), MAX_INT);

        // Retrieve the address of the BUSD/WBNB liquidity pool
        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(
            _busdBorrow,
            WBNB
        );
        require(pair != address(0), "Pool does not exist"); // Ensure the pool exists

        // Determine the token0 (WBNB) and token1 (BUSD) in the pair
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        // Determine the amount to swap (either token0 or token1) based on the borrowed token
        uint amount0Out = _busdBorrow == token0 ? _amount : 0;
        uint amount1Out = _busdBorrow == token1 ? _amount : 0;

        // Initiate the swap and pass the encoded data for repayment
        bytes memory data = abi.encode(_busdBorrow, _amount, msg.sender);
        IUniswapV2Pair(pair).swap(amount0Out, amount1Out, address(this), data);
    }

    // Called by the Uniswap pair contract to execute the flash loan repayment and arbitrage strategy
    function pancakeCall(
        address _sender,
        uint256 _amount0,
        uint256 _amount1,
        bytes calldata _data
    ) external {
        // Ensure the call originates from the correct liquidity pool pair
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        address pair = IUniswapV2Factory(PANCAKE_FACTORY).getPair(
            token0,
            token1
        );
        require(msg.sender == pair, "The sender needs to match the pair");
        require(_sender == address(this), "Sender should match the contract");

        // Decode the data to extract the loan amount and initiating address
        (address busdBorrow, uint256 amount, address myAddress) = abi.decode(
            _data,
            (address, uint256, address)
        );

        // Calculate the repayment amount with a 0.3% fee
        uint256 fee = ((amount * 3) / 997) + 1;
        uint256 repayAmount = amount + fee;

        // Execute the arbitrage by trading between different token pairs
        uint256 loanAmount = _amount0 > 0 ? _amount0 : _amount1;
        uint256 trade1Coin = placeTrade(BUSD, CROX, loanAmount);
        uint256 trade2Coin = placeTrade(CROX, CAKE, trade1Coin);
        uint256 trade3Coin = placeTrade(CAKE, BUSD, trade2Coin);

        // Check if the arbitrage was profitable
        bool profCheck = checkResult(repayAmount, trade3Coin);
        require(profCheck, "Arbitrage not profitable");

        // Transfer the profit to the initiator
        IERC20 otherToken = IERC20(BUSD);
        otherToken.transfer(myAddress, trade3Coin - repayAmount);

        // Repay the flash loan
        IERC20(busdBorrow).transfer(pair, repayAmount);
    }
}