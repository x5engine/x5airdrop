import React, { useState } from "react";
import "./styles.css";
import "antd/dist/antd.css";
import { Button } from "antd";
import { DownloadOutlined } from "@ant-design/icons";
import abi from "./abi.json";
import Web3 from "web3";

const endpoint =
  "https://rinkeby.infura.io/v3/752e6cd46a9343ff8fa19dcf3aff6041";
const web3 = new Web3(new Web3.providers.HttpProvider(endpoint));
//RINKEBY
const airdrop = new web3.eth.Contract(
  abi,
  "0x7e8eAdDb06ae8CFffDcC102F8a415D7ADD7AD19d"
);

export default function App() {
  const [action, setAction] = useState("ready");

  const airdropIt = () => {
    setAction("incoming");
    airdrop.methods.drop().then((error, result) => {
      console.log(error, result);
      setAction("done");
    });
  };

  return (
    <div className="App">
      <h1>Airdrop</h1>
      <h4>{action}</h4>
      <h2>Start to share some magic tokens!</h2>
      <img
        src="https://image.flaticon.com/icons/svg/1487/1487521.svg"
        width="224"
        height="224"
        alt="Airdrop icon"
        title="Airdrop icon"
      />

      <br />
      <br />
      <br />
      <div>
        <Button
          type="primary"
          shape="round"
          icon={<DownloadOutlined />}
          size={"large"}
          onClick={airdropIt}
        >
          Launch Airdrop
        </Button>
      </div>
    </div>
  );
}

//https://thumbs.gfycat.com/HilariousBriefBullfrog-mobile.mp4
