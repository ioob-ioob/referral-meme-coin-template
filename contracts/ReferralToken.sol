// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title ReferralToken
 * @dev A simple ERC20 token contract with referral and developer fees.
 */
contract ReferralToken is IERC20, IERC20Metadata, Ownable {
    using SafeMath for uint256;

    string private _name; // Token name
    string private _symbol; // Token symbol
    uint8 private _decimals = 18; // Token decimals
    uint256 private _totalSupply; // Total token supply

    // Balances of each account
    mapping(address => uint256) private _balances;

    // Allowances for each account to spend tokens of another account
    mapping(address => mapping(address => uint256)) private _allowances;

    // Mapping of accounts to their referrers
    mapping(address => address) public referralOf;

    // Referral fee percentage (0.05% by default)
    uint256 public referralFee = 5;

    // Developer fee percentage (0.1% by default)
    uint256 public devFee = 10;

    /**
     * @dev Constructor to initialize the token.
     * @param name_ The name of the token.
     * @param symbol_ The symbol of the token.
     * @param initialSupply The initial supply of the token.
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 initialSupply,
        uint256 _referralFee,
        uint256 _devFee
    ) Ownable(msg.sender) {
        require(_referralFee <= 500, "ReferralToken: Fee cannot exceed 5%");
        require(_devFee <= 500, "ReferralToken: Fee cannot exceed 5%");
        require(
            _referralFee <= _devFee,
            "ReferralToken: Referral fee cannot be greater than dev fee"
        );
        _name = name_;
        _symbol = symbol_;
        _totalSupply = initialSupply * (10 ** uint256(_decimals));
        _balances[msg.sender] = _totalSupply;
        referralFee = _referralFee;
        devFee = _devFee;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    /**
     * @dev Set new referralFee.
     * @param newFee new fee in bp.
     */
    function setReferralFee(uint256 newFee) external onlyOwner {
        require(newFee <= 500, "ReferralToken: Fee cannot exceed 5%");
        require(
            newFee <= devFee,
            "ReferralToken: Referral fee cannot be greater than dev fee"
        );
        referralFee = newFee;
    }

    /**
     * @dev Set new devFee.
     * @param newFee new fee in bp.
     */
    function setDevFee(uint256 newFee) external onlyOwner {
        require(newFee <= 500, "ReferralToken: Fee cannot exceed 5%");
        require(
            newFee >= referralFee,
            "ReferralToken: Dev fee cannot be less than referral fee"
        );
        devFee = newFee;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the total supply of the token.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev Returns the balance of the specified account.
     * @param account The address of the account.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev Transfers tokens from the sender to the recipient.
     * @param recipient The address of the recipient.
     * @param amount The amount of tokens to transfer.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev Returns the allowance of spender to spend tokens on behalf of the owner.
     * @param owner The address of the owner.
     * @param spender The address of the spender.
     */
    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev Approves spender to spend amount of tokens on behalf of the sender.
     * @param spender The address of the spender.
     * @param amount The amount of tokens to approve.
     */
    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev Transfers tokens from one address to another.
     * @param sender The address to transfer tokens from.
     * @param recipient The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            msg.sender,
            _allowances[sender][msg.sender].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    /**
     * @dev Sets the referrer for the calling account.
     * @param referrer The address of the referrer.
     */
    function setReferral(address referrer) external {
        require(
            referrer != address(0),
            "ReferralToken: Referrer cannot be the zero address"
        );
        require(
            referrer != msg.sender,
            "ReferralToken: Self-referral is disallowed"
        );
        require(
            referralOf[msg.sender] == address(0),
            "ReferralToken: Referrer already set"
        );

        referralOf[msg.sender] = referrer;
    }

    /**
     * @dev Internal function to transfer tokens.
     * @param sender The address to transfer tokens from.
     * @param recipient The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "ERC20: Transfer amount must be greater than zero");

        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );

        _balances[sender] = senderBalance - amount;

        // Calculate referral and developer fees
        uint256 feeAmount = 0;
        if (referralOf[sender] != address(0)) {
            feeAmount = amount.mul(referralFee).div(10000);
            _balances[referralOf[sender]] = _balances[referralOf[sender]].add(
                feeAmount
            );
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

    /**
     * @dev Internal function to approve spender to spend amount of tokens on behalf of the owner.
     * @param owner The address of the owner.
     * @param spender The address of the spender.
     * @param amount The amount of tokens to approve.
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
}
