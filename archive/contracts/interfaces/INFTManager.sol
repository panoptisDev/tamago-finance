// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

// import "./IPancakePair.sol";
import "./ISyntheticNFT.sol";

interface INFTManager {

    function syntheticNFT() external view returns (ISyntheticNFT);

    // function collateralShare() external view returns (IPancakePair);

}