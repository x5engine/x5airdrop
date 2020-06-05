// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "https://github.com/x5engine/openzeppelin-contracts/blob/v3.0.1x/contracts/GSN/Context.sol";
import "https://github.com/x5engine/openzeppelin-contracts/blob/v3.0.1x/contracts/math/SafeMath.sol";
import "https://github.com/x5engine/openzeppelin-contracts/blob/v3.0.1x/contracts/access/Ownable.sol";
import "https://github.com/x5engine/openzeppelin-contracts/blob/v3.0.1x/contracts/access/AccessControl.sol";

/**
 * @title Airdrop
 * @dev This contract allows to Airdrop Ether or any ERC20 and ERC721 Tokens among a group of accounts. The sender does not need to be aware
 * that the Tokens will be split in this way, since it is handled transparently by the contract.
 *
 * The split can be in equal parts or in any other arbitrary proportion. The way this is specified is by assigning each
 * account to a number of shares. Of all the Tokens that this contract receives, each account will then be able to claim
 * an amount proportional to the percentage of total shares they were assigned.
 *
 * `PaymentSplitter` follows a _pull payment_ model. This means that payments are not automatically forwarded to the
 * accounts but kept in this contract, and the actual transfer is triggered as a separate step by calling the {release}
 * function.
 */

contract Airdrop is Context, Ownable, AccessControl {
    using SafeMath for uint256;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");//admin role
    bytes32 public constant MOD_ROLE = keccak256("MOD_ROLE");//moderator role
    
    
    event AirdropDone(uint256 account);
    event ModAdded(address account);
    event ModRemoved(address account);
    event AccountBanned(address account);

    event PayeeAdded(address account, uint256 shares);
    event PayeeUpdated(address account, uint256 shares);
    event PayeeRemoved(address account);
    event PaymentReleased(address to, uint256 amount);
    event PaymentReceived(address from, uint256 amount);

    uint256 private _totalShares;
    uint256 private _totalReleased;

    mapping(address => uint256) private _shares;
    mapping(address => uint256) private _released;
    address[] private _payees;
    address[] private _banlist;//banned accounts

    /**
     * @dev Creates an instance of `PaymentSplitter` where each account in `payees` is assigned the number of shares at
     * the matching position in the `shares` array.
     *
     * All addresses in `payees` must be non-zero. Both arrays must have the same non-zero length, and there must be no
     * duplicates in `payees`.
     */
    constructor (address[] memory payees, uint256[] memory shares) public payable {
        // solhint-disable-next-line max-line-length
        require(payees.length == shares.length, "PaymentSplitter: payees and shares length mismatch");
        require(payees.length > 0, "PaymentSplitter: no payees");
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        for (uint256 i = 0; i < payees.length; i++) {
            _addPayee(payees[i], shares[i]);
        }
    }


    modifier onlyAdmin {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin! Can't touch this!");
        _;
    }
    
    modifier onlyAdminOrMod {
        require(hasRole(ADMIN_ROLE, msg.sender) || hasRole(MOD_ROLE, msg.sender), "Caller is not an admin or moderator");
        _;
    }
    
    /**
     * @dev The Ether received will be logged with {PaymentReceived} events. Note that these events are not fully
     * reliable: it's possible for a contract to receive Ether without triggering this function. This only affects the
     * reliability of the events, and not the actual splitting of Ether.
     *
     * To learn more about this see the Solidity documentation for
     * https://solidity.readthedocs.io/en/latest/contracts.html#fallback-function[fallback
     * functions].
     */
    receive () external payable virtual {
        emit PaymentReceived(_msgSender(), msg.value);
    }

    /**
     * @dev Getter for the total shares held by payees.
     */
    function totalShares() public view returns (uint256) {
        return _totalShares;
    }

    /**
     * @dev Getter for the total amount of Ether already released.
     */
    function totalReleased() public view returns (uint256) {
        return _totalReleased;
    }

    /**
     * @dev Getter for the count of the payees.
     */
    function totalPayees() public view returns (uint256) {
        return _payees.length;
    }
    
    /**
     * @dev Getter for the amount of shares held by an account.
     */
    function shares(address account) public view returns (uint256) {
        return _shares[account];
    }

    /**
     * @dev Getter for the amount of Ether already released to a payee.
     */
    function released(address account) public view returns (uint256) {
        return _released[account];
    }

    /**
     * @dev Getter for the address of the payee number `index`.
     */
    function payee(uint256 index) public view returns (address) {
        return _payees[index];
    }

    /**
     * @dev Triggers a transfer to `account` of the amount of Ether they are owed, according to their percentage of the
     * total shares and their previous withdrawals.
     */
    function release(address payable account) public virtual onlyAdminOrMod {
        require(_shares[account] > 0, "PaymentSplitter: account has no shares");

        uint256 totalReceived = address(this).balance.add(_totalReleased);
        uint256 payment = totalReceived.mul(_shares[account]).div(_totalShares).sub(_released[account]);

        require(payment != 0, "PaymentSplitter: account is not due payment");

        _released[account] = _released[account].add(payment);
        _totalReleased = _totalReleased.add(payment);

        account.transfer(payment);
        emit PaymentReleased(account, payment);
    }

    /**
     * @dev Add a new payee to the contract.
     * @param account The address of the payee to add.
     * @param shares_ The number of shares owned by the payee.
     */
    function _addPayee(address account, uint256 shares_) private {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(shares_ > 0, "PaymentSplitter: shares are 0");
        require(_shares[account] == 0, "PaymentSplitter: account already has shares");

        _payees.push(account);
        _shares[account] = shares_;
        _totalShares = _totalShares.add(shares_);
        emit PayeeAdded(account, shares_);
    }
    
    function addPayee(address account, uint256 shares_) public onlyAdminOrMod {
        _addPayee(account,shares_);
    }
    
    function removePayee(address account) public onlyAdminOrMod {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        // _payees.push(account);
        // _shares[account] = shares_;
        // _totalShares = _totalShares.add(shares_);
        emit PayeeRemoved(account);
    }

    // releases the shares to each member aka payee
    function drop() public onlyAdminOrMod {// Airdrop only admins and moderator
        // uint256 count = totalPayees();
        // release(payable(_payees[0]));
        for (uint256 i = 0; i < _payees.length; i++) {
          release(payable(_payees[i]));
        }
        emit AirdropDone(_payees.length);
    }
    
        /**
     * @dev Bann account
     * @param account The address of the payee to add.
     */
    function ban(address account) public onlyAdminOrMod {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(_shares[account] == 0, "PaymentSplitter: account already has shares");

        _banlist.push(account);
        emit AccountBanned(account);
    }
    
    /**
     * @dev Updates an existant payee share
     * @param account The address of the payee to add.
     * @param shares_ The number of shares owned by the payee.
     */
    function updateShare(address account, uint256 shares_) public onlyAdminOrMod {
        require(account != address(0), "PaymentSplitter: account is the zero address");
        require(shares_ > 0, "PaymentSplitter: shares are 0");
        require(_shares[account] == 0, "PaymentSplitter: account already has shares");
        uint256 oldShares =_shares[account];
        _shares[account] = shares_;
        _totalShares = _totalShares.sub(oldShares);
        _totalShares = _totalShares.add(shares_);
        emit PayeeUpdated(account, shares_);
    }
    
    function addMod(address payable account) public onlyAdmin {
        grantRole(MOD_ROLE, account);
        emit ModAdded(account);
    }

    function removeMod(address payable account) public onlyAdmin {
        super.revokeRole(MOD_ROLE, account);
        emit ModRemoved(account);
    }

}

/* test values
sender "0xD277a99c0d08DED3bDB253024bfF81E41496465c"

Injected values
4 payees

["0x87fBFeAbB807B72c05Ff8b3B13CCEa719271f1C2","0x3A02E27b4d16F23AA1f62105f9673CA964bd3CAA","0x47070994a00C4d2b25D8f8f08019c5bCC087D2b9","0x20d448966D99F24d457647B13Ffea11b3e1dbb30"]

4 Shares 
[2,1,5,3]


VM values

["0x7CFB04FAcB9A2302130a67f21385565F58b10deA", "0x086729764CE47D688410E4A7d519bfff84B7d129","0x1FDc4C85cda036E4c7D3D5D5E7EC40dC025345a1"]

[2,1,5]

//for reading reentracy
https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/
https://hackingdistributed.com/2016/06/18/analysis-of-the-dao-exploit/
*/