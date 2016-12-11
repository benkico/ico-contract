pragma solidity ^0.4.2;
import "AbstractHumaniqToken.sol";


/// @title HumaniqICO contract - Takes funds from users and issues tokens.
/// @author Evgeny Yurtaev - <evgeny@etherionlab.com>
contract HumaniqICO {

    /*
     * External contracts
     */
    HumaniqToken public humaniqToken = HumaniqToken(0x0);

    /*
     * Crowdfunding parameters
     */
    uint constant public CROWDFUNDING_PERIOD = 14 days; // 1 month
    uint constant public CROWDSALE_TARGET = 10000; // Goal threshold, 10000 ETH

    /*
     *  Storage
     */
    address public founder;
    address public multisig;
    uint public startDate;
    uint public icoBalance;
    uint public baseTokenPrice = 666 szabo; // 0.000666 ETH
    uint public discountedPrice = baseTokenPrice;
    bool public isICOActive = false;

    // participant address => value in Wei
    mapping (address => uint) public investments;

    /*
     *  Modifiers
     */
    modifier noEther() {
        if (msg.value > 0) {
            throw;
        }
        _;
    }

    modifier onlyFounder() {
        // Only founder is allowed to do this action.
        if (msg.sender != founder) {
            throw;
        }
        _;
    }

    modifier minInvestment() {
        // User has to send at least the ether value of one token.
        if (msg.value < baseTokenPrice) {
            throw;
        }
        _;
    }

    modifier icoActive() {
        if (isICOActive == false) {
            throw;
        }
        _;
    }

    modifier timedTransitions() {
        uint icoDuration = now - startDate;
        if (icoDuration >= 10 days) {
            discountedPrice = baseTokenPrice;
        }
        else if (icoDuration >= 7 days) {
            discountedPrice = (baseTokenPrice * 100) / 107;
        }
        else if (icoDuration >= 4 days) {
            discountedPrice = (baseTokenPrice * 100) / 120;
        }
        else if (icoDuration >= 1 days) {
            discountedPrice = (baseTokenPrice * 100) / 142;
        }
        else if (icoDuration >= 12 hours) {
            discountedPrice = (baseTokenPrice * 100) / 150;
        }
        else {
            discountedPrice = (baseTokenPrice * 100) / 170;
        }
        _;
    }

    /*
     *  Contract functions
     */
    /// @dev Checks if crowdfunding has finished and the amount of money
    /// collected is higher than crowdfunding goal.
    function hasFinishedSuccessfully() constant internal returns (bool) {
        if ((isICOActive == false) && (icoBalance > CROWDSALE_TARGET)) {
            return true;
        }
        return false;
    }

    /// @dev Changes status of ICO to inactive if crowdfunding period has finished.
    function updateICOStatus() internal {
      if (isICOActive == true) {
        uint icoDuration = now - startDate;
        if (icoDuration >= CROWDFUNDING_PERIOD) {
            isICOActive = false;
        }
      }
    }

    /// @dev Allows user to create tokens if token creation is still going
    /// and cap was not reached. Returns token count.
    function fund()
        external
        timedTransitions
        icoActive
        minInvestment
        payable
        returns (uint)
    {
        // Token count is rounded down. Sent ETH should be multiples of baseTokenPrice.
        uint tokenCount = msg.value / discountedPrice;
        // Ether spent by user.
        uint investment = tokenCount * discountedPrice;
        // Send change back to user.
        if (msg.value > investment && !msg.sender.send(msg.value - investment)) {
            throw;
        }
        // Update fund's and user's balance and total supply of tokens.
        icoBalance += investment;
        investments[msg.sender] += investment;
        if (!humaniqToken.issueTokens.value(0)(msg.sender, tokenCount)) {
            // Tokens could not be issued.
            throw;
        }
        return tokenCount;
    }

    /// @dev Issues tokens for users who made BTC purchases.
    /// @param beneficiary Address the tokens will be issued to.
    /// @param _tokenCount Number of tokens to issue.
    function fundBTC(address beneficiary, uint _tokenCount)
        external
        timedTransitions
        icoActive
        onlyFounder
        returns (uint)
    {
        // Approximate ether spent.
        uint investment = _tokenCount * discountedPrice;
        // Update fund's and user's balance and total supply of tokens.
        // Do not update individual investment, because user paid in BTC.
        icoBalance += investment;
        if (!humaniqToken.issueTokens.value(0)(beneficiary, _tokenCount)) {
            // Tokens could not be issued.
            throw;
        }
        return _tokenCount;
    }

    /// @dev Allows user to withdraw ETH if token creation period ended and
    /// crowdfunding target was not reached. Returns success.
    function withdrawFunding()
        external
        noEther
        returns (bool)
    {
        // Update current ICO status.
        updateICOStatus();
        // If ICO is still going or ICO has successfully finised, throw.
        if ((isICOActive == true) || (hasFinishedSuccessfully() == true)) {
          throw;
        }
        // Continue only if ICO failed to meet the threshold.
        uint investment = investments[msg.sender];
        investments[msg.sender] = 0;
        icoBalance -= investment;
        // Send ETH back to user.
        if (investment > 0  && !msg.sender.send(investment)) {
            throw;
        }
        return true;
    }

    /// @dev If ICO has successfully finished sends the money to multisig
    /// wallet.
    function finishCrowdsale()
        external
        noEther
        onlyFounder
        returns (bool)
    {
      if (hasFinishedSuccessfully()) {
        if (!multisig.send(this.balance)) {
          // Could not send money
          throw;
        }
      }
    }

    /// @dev Sets token value in Wei.
    /// @param valueInWei New value.
    function changeBaseTokenPrice(uint valueInWei)
        external
        noEther
        onlyFounder
        returns (bool)
    {
        baseTokenPrice = valueInWei;
        return true;
    }

    /// @dev Function that activates ICO.
    function startICO()
        external
        onlyFounder
        noEther
    {
        if (isICOActive == false) {
          // Start ICO
          isICOActive = true;
          // Set start-date of token creation
          startDate = now;
        }
    }

    /// @dev Contract constructor function sets founder and multisig addresses.
    function HumaniqICO(address _multisig) noEther {
        // Set founder address
        founder = msg.sender;
        // Set multisig address
        multisig = _multisig;
    }

    /// @dev Fallback function always fails. Use fund function to create tokens.
    function () {
        throw;
    }
}
