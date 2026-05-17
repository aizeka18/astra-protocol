// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./YieldVault.sol";

contract YieldVaultV2 is YieldVault {
    bool public emergencyPaused;

    event EmergencyPauseUpdated(bool paused);

    function setEmergencyPause(bool paused) external onlyOwner {
        emergencyPaused = paused;

        emit EmergencyPauseUpdated(paused);
    }

    function version() external pure returns (string memory) {
        return "V2";
    }
}
