// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@hyperledger-labs/yui-ibc-solidity/contracts/core/IBCHandler.sol";
import "@hyperledger-labs/yui-ibc-solidity/contracts/core/IBCHost.sol";
import "@hyperledger-labs/yui-ibc-solidity/contracts/core/IBCModule.sol";
import "@hyperledger-labs/yui-ibc-solidity/contracts/core/types/Channel.sol";
import "@hyperledger-labs/yui-ibc-solidity/contracts/lib/Bytes.sol";
import "../lib/Packet.sol";

contract MiniToken is IModuleCallbacks {
    address private owner;
    IBCHandler ibcHandler;
    IBCHost ibcHost;

    using Bytes for *;

    constructor(IBCHost host_, IBCHandler ibcHandler_) public {
        owner = msg.sender;

        ibcHost = host_;
        ibcHandler = ibcHandler_;
    }

    mapping(address => uint256) private _balances;

    modifier onlyOwner() {
        require(msg.sender == owner, "MiniToken: caller is not the owner");
        _;
    }

    modifier onlyIBC() {
        require(
            msg.sender == address(ibcHandler),
            "MiniToken: caller is not the ibcHandler"
        );
        _;
    }

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
        require(_balances[msg.sender] >= amount, "Token: amount shortage");
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        require(account != address(0), "Token: invalid address");
        return _balances[account];
    }

    function sendTransfer(
                          string calldata denom,
                          uint64 amount,
                          address receiver,
                          string calldata sourcePort,
                          string calldata sourceChannel,
                          uint64 timeoutHeight
                          ) external {
    require(_burn(msg.sender, amount));

    _sendPacket(
                MiniTokenPacketData.Data({
                    amount: amount,
                    sender: abi.encodePacked(msg.sender),
                    receiver: abi.encodePacked(receiver)
                    }),
                sourcePort,
                sourceChannel,
                timeoutHeight
                );
    }

    function onRecvPacket(Packet.Data calldata packet) onlyIBC external virtual override returns (bytes memory acknowledgement) {
        MiniTokenPacketData.Data memory data = MiniTokenPacketData.decode(packet.data);
        return
            _newAcknowledgement(_mint(data.receiver.toAddress(), data.amount));
    }

    function onAcknowledgementPacket(Packet.Data calldata packet, bytes calldata acknowledgement) onlyIBC external virtual override {
        if (!_isSuccessAcknowledgement(acknowledgement)) {
            _refundTokens(MiniTokenPacketData.decode(packet.data));
        }
    }

    function onChanOpenInit(
        Channel.Order,
        string[] calldata connectionHops,
        string calldata portId,
        string calldata channelId,
        ChannelCounterparty.Data calldata counterparty,
        string calldata version
    ) external virtual override {}

    function onChanOpenTry(
        Channel.Order,
        string[] calldata connectionHops,
        string calldata portId,
        string calldata channelId,
        ChannelCounterparty.Data calldata counterparty,
        string calldata version,
        string calldata counterpartyVersion
    ) external virtual override {}

    function onChanOpenAck(
        string calldata portId,
        string calldata channelId,
        string calldata counterpartyVersion
    ) external virtual override {}

    function onChanOpenConfirm(
        string calldata portId,
        string calldata channelId
    ) external virtual override {}

    function onChanCloseConfirm(
        string calldata portId,
        string calldata channelId
    ) external virtual override {}

    function onChanCloseInit(
        string calldata portId,
        string calldata channelId
    ) external virtual override {}

    // Internal Functions //

    function _sendPacket(
        MiniTokenPacketData.Data memory data,
        string memory sourcePort,
        string memory sourceChannel,
        uint64 timeoutHeight
    ) internal virtual {
        (Channel.Data memory channel, bool found) = ibcHost.getChannel(
            sourcePort,
            sourceChannel
        );
        require(found, "MiniToken: channel not found");
        ibcHandler.sendPacket(
            Packet.Data({
                sequence: ibcHost.getNextSequenceSend(
                    sourcePort,
                    sourceChannel
                ),
                source_port: sourcePort,
                source_channel: sourceChannel,
                destination_port: channel.counterparty.port_id,
                destination_channel: channel.counterparty.channel_id,
                data: MiniTokenPacketData.encode(data),
                timeout_height: Height.Data({
                    revision_number: 0,
                    revision_height: timeoutHeight
                }),
                timeout_timestamp: 0
            })
        );
    }

    function _newAcknowledgement(bool success)
        internal
        pure
        virtual
        returns (bytes memory)
    {
        bytes memory acknowledgement = new bytes(1);
        if (success) {
            acknowledgement[0] = 0x01;
        } else {
            acknowledgement[0] = 0x00;
        }
        return acknowledgement;
    }

    function _isSuccessAcknowledgement(bytes memory acknowledgement)
        internal
        pure
        virtual
        returns (bool)
    {
        require(acknowledgement.length == 1);
        return acknowledgement[0] == 0x01;
    }

    function _refundTokens(MiniTokenPacketData.Data memory data)
        internal
        virtual
    {
        require(_mint(data.sender.toAddress(), data.amount));
    }
}
