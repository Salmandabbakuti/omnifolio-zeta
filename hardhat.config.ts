import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@zetachain/toolkit/tasks";
import { getHardhatConfigNetworks } from "@zetachain/networks";

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  defaultNetwork: "localhost",
  networks: {
    ...getHardhatConfigNetworks()
  }
};

export default config;
