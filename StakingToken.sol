// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingToken is ERC20, ERC20Burnable, Ownable {
    uint8 private _decimals;
    uint256 private _totalBurned;

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function totalBurned() public view returns (uint256) {
        return _totalBurned;
    }

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function mint(address account, uint256 amount) external onlyOwner returns (bool) {
        _mint(account, amount);
        return true;
    }

    function _burn(address account, uint256 amount) internal override {
        super._burn(account, amount);
        _totalBurned += amount;
    }
}
