-include .env
.PHONY: all test clean build deploy fund help install snapshot format anvil 

all: clean remove install update build test deploy anvil

start: install build

ANVIL_RPC_URL := http://127.0.0.1:8545
ANVIL_PRIVATE_KEY := ac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

clean :; forge clean

# Remove modules and lib
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

# Install all dependencies
install :; forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install openzeppelin/openzeppelin-contracts --no-commit

# Update Dependencies
update :; forge update

build :; forge build

# Test commands
test :; forge test

coverage :; forge coverage --report debug > coverage-report.txt

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'local test test test test test test test test test test test junk' --steps-tracing --block-time 1
NETWORK_ARGS := --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --private-key $(SEPOLIA_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy:
	@forge script script/DeployInvestMint.s.sol:DeployInvestMint ${NETWORK_ARGS}
