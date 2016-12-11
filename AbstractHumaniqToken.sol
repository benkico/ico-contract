pragma solidity ^0.4.2;
import "AbstractToken.sol";

contract HumaniqToken is Token {
    function issueTokens(address _for, uint tokenCount) payable returns (bool);
    function changeEmissionContractAddress(address newAddress) returns (bool);
}
