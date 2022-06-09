contract MiniToken {
    address private owner;

    constructor() public {
        owner = msg.sender;
    }

    mapping(address => uint256) private _balances;

    function mint(address account, uint256 amount) onlyOwner external {
        require(_mint(account, amount), "invalid address");
    }

    function _mint(address account, uint256 amount) internal returns (bool) {
        if (account == address(0)) {
            return false;
        }
        _balances[account] += amount;
        return true;
    }

    function burn(address account, uint256 amount) onlyOwner external {
        _burn(account, amount);
    }

    function _burn(address account, uint256 amount) internal returns (bool) {
        uint256 accountBalance = _balances[account];
        if (accountBalance < amount) {
            return false;
        }
        _balances[account] = accountBalance - amount;
        return true;
    }

    function transfer(address to, uint256 amount) external {
        require(to != address(0), "Token: invalid address");
        uint256 balance = _balances[msg.sender];
        require(_balances[msg.sender] >= amount, "Token: amount shortage");
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        require(account != address(0), "Token: invalid address");
        return _balances[account];
    }
}
