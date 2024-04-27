// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ReferralToken is IERC20, IERC20Metadata, Ownable {
    using SafeMath for uint256;

    string private _name;
    string private _symbol;
    uint8 private _decimals = 18;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    mapping(address => address) public referralOf; // Maps an account to its referrer
    uint256 public referralFee = 50;  // Referral fee 0.05%
    uint256 public devFee = 100;      // Developer fee 0.1%

    constructor(string memory name_, string memory symbol_, uint256 initialSupply) Ownable(msg.sender) {
        _name = name_;
        _symbol = symbol_;
        _totalSupply = initialSupply * (10 ** uint256(_decimals));
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function setReferral(address referrer) external {
        require(referrer != address(0), "ReferralToken: Referrer cannot be the zero address");
        require(referrer != msg.sender, "ReferralToken: Self-referral is disallowed");
        require(referralOf[msg.sender] == address(0), "ReferralToken: Referrer already set");

        referralOf[msg.sender] = referrer;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "ERC20: Transfer amount must be greater than zero");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");

        _balances[sender] = senderBalance - amount;

        // Calculate referral and developer fees
        uint256 feeAmount = 0;
        if(referralOf[sender] != address(0)) {
            feeAmount = amount.mul(referralFee).div(10000);
            _balances[referralOf[sender]] = _balances[referralOf[sender]].add(feeAmount);
            emit Transfer(sender, referralOf[sender], feeAmount);
        } else {
            feeAmount = amount.mul(devFee).div(10000);
            _balances[owner()] = _balances[owner()].add(feeAmount);
            emit Transfer(sender, owner(), feeAmount);
        }

        uint256 receiveAmount = amount.sub(feeAmount);
        _balances[recipient] = _balances[recipient].add(receiveAmount);
        emit Transfer(sender, recipient, receiveAmount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}
