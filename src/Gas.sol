// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

interface IGasContract {
    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }

    struct Payment {
        PaymentType paymentType;
        uint256 paymentID;
        bool adminUpdated;
        string recipientName;
        address recipient;
        address admin;
        uint256 amount;
    }

    struct History {
        uint256 lastUpdate;
        address updatedBy;
        uint256 blockNumber;
    }

    struct ImportantStruct {
        uint256 amount;
        uint256 valueA;
        uint256 bigValue;
        uint256 valueB;
        bool paymentStatus;
        address sender;
    }

    function getPaymentHistory() external payable returns (History[] memory paymentHistory_);

    function checkForAdmin(address _user) external view returns (bool admin_);

    function balanceOf(address _user) external view returns (uint256 balance_);

    function getTradingMode() external pure returns (bool mode_);

    function addHistory(address _updateAddress, bool _tradeMode) external returns (bool status_, bool tradeMode_);

    function transfer(address _recipient, uint256 _amount, string calldata _name) external returns (bool status_);

    function updatePayment(address _user, uint256 _ID, uint256 _amount, PaymentType _type) external;

    function addToWhitelist(address _userAddrs, uint256 _tier) external;

    function whiteTransfer(address _recipient, uint256 _amount) external;

    function getPaymentStatus(address sender) external view returns (bool, uint256);

    event Transfer(address indexed recipient, uint256 amount);
    event PaymentUpdated(address indexed admin, uint256 paymentID, uint256 amount, string recipientName);
    event AddedToWhitelist(address indexed user, uint256 tier);
    event WhiteListTransfer(address indexed recipient);
    event supplyChanged(address indexed admin, uint256 newSupply);
}

contract Constants {
    uint256 constant tradeFlag = 1;
    uint256 constant dividendFlag = 1;
}

contract GasContract is IGasContract, Constants {
    uint256 totalSupply; // cannot be updated
    uint256 paymentCounter;
    mapping(address => uint256) public balances;
    uint256 constant tradePercent = 12;
    mapping(address => Payment[]) public payments;
    mapping(address => uint256) public whitelist;
    address[5] public administrators;
    address immutable contractOwner;

    PaymentType constant defaultPayment = PaymentType.Unknown;

    History[] internal paymentHistory; // when a payment was updated


    uint256 wasLastOdd = 1;
    mapping(address => uint256) public isOddWhitelistUser;


    mapping(address => ImportantStruct) public whiteListStruct;


    function _onlyAdminOrOwner() internal view {
        if ( msg.sender != contractOwner) {
            revert();
        }
    }

    function _checkIfWhiteListed(address sender) internal view {
        uint256 usersTier = whitelist[msg.sender];
        if (msg.sender != sender || usersTier > 4 || usersTier == 0) revert();
    }

  

    constructor(address[] memory _admins, uint256 _totalSupply) {
        totalSupply = _totalSupply;
        contractOwner = msg.sender;
        for (uint256 ii = 0; ii < administrators.length; ++ii) {
            if (_admins[ii] != address(0)) {
                administrators[ii] = _admins[ii];
                if (_admins[ii] == msg.sender) {
                    balances[msg.sender] = totalSupply;
                    emit supplyChanged(_admins[ii], totalSupply);
                } else {
                    emit supplyChanged(_admins[ii], 0);
                }
            }
        }
    }

    function getPaymentHistory() public override payable returns (History[] memory paymentHistory_) {
        return paymentHistory;
    }

    function checkForAdmin(address _user) external view override returns (bool admin_) {
        return _user == contractOwner;
    }

    function balanceOf(address _user) external view override returns (uint256 balance_) {
        return balances[_user];
    }

    function getTradingMode() public pure override returns (bool mode_) {
        return tradeFlag == 1 || dividendFlag == 1;
    }

    function addHistory(address _updateAddress, bool _tradeMode) public override returns (bool status_, bool tradeMode_) {
        History memory history;
        history.blockNumber = block.number;
        history.lastUpdate = block.timestamp;
        history.updatedBy = _updateAddress;
        paymentHistory.push(history);
        //Status array why is it used? DELETED
        return (true, _tradeMode);
    }

    function transfer(address _recipient, uint256 _amount, string calldata _name) external override returns (bool status_) {
        if(balances[msg.sender] < _amount || bytes(_name).length > 9){
            revert();
        }
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
        Payment memory payment;
        payment.admin = address(0);
        payment.paymentType = PaymentType.BasicPayment;
        payment.recipient = _recipient;
        payment.amount = _amount;
        payment.recipientName = _name;
        payment.paymentID = ++paymentCounter;
        payments[msg.sender].push(payment);
        
        return true;
    }

    function updatePayment(address _user, uint256 _ID, uint256 _amount, PaymentType _type) external override {
        _onlyAdminOrOwner();
        if (_ID <= 0 || _amount <= 0 || _user == address(0)) {
            revert();
        }

        for (uint256 ii = 0; ii < payments[_user].length; ++ii) {
           
                payments[_user][ii].adminUpdated = true;
                payments[_user][ii].admin = _user;
                payments[_user][ii].paymentType = _type;
                payments[_user][ii].amount = _amount;
                bool tradingMode = getTradingMode();
                addHistory(_user, tradingMode);
                emit PaymentUpdated(msg.sender, _ID, _amount, payments[_user][ii].recipientName);
            
        }
    }

    function addToWhitelist(address _userAddrs, uint256 _tier) public override {
        _onlyAdminOrOwner(); 
        uint256 userBalance =  whitelist[_userAddrs];
        if (_tier >= 255) revert();
        if (_tier > 3) {
            userBalance = 3;
        } else if (_tier == 1) {
            userBalance = 1;
        } else if (_tier > 0 && _tier < 3) {
            userBalance = 2;
        } else{
            userBalance = _tier;
        }
        whitelist[_userAddrs] = userBalance;
        uint256 wasLastAddedOdd = wasLastOdd;
        if (wasLastAddedOdd == 1) {
            wasLastOdd = 0;
        } else if (wasLastAddedOdd == 0) {
            wasLastOdd = 1;
        } else {
            revert();
        }
        isOddWhitelistUser[_userAddrs] = wasLastAddedOdd;
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(address _recipient, uint256 _amount) external override {
        _checkIfWhiteListed(msg.sender);
        whiteListStruct[msg.sender] = ImportantStruct(_amount, 0, 0, 0, true, msg.sender);
        if (balances[msg.sender] < _amount || _amount < 3) {
            revert();
        }
        
        balances[msg.sender] = balances[msg.sender] - _amount + whitelist[msg.sender];
        balances[_recipient] = balances[_recipient] + _amount - whitelist[msg.sender];
 
        emit WhiteListTransfer(_recipient);
    }

    function getPaymentStatus(address sender) external view  override returns (bool, uint256) {
        return (whiteListStruct[sender].paymentStatus, whiteListStruct[sender].amount);
    }

    receive() external payable {
        payable(msg.sender).transfer(msg.value);
    }

    fallback() external payable {
        payable(msg.sender).transfer(msg.value);
    }
}
