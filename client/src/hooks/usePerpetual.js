import { useMemo, useEffect, useState, useCallback } from "react"
import { ethers } from "ethers"
import Perpetual from "../abi/Perpetual.json"
import { useERC20 } from "./useERC20"

const Side = {
  FLAT: 0,
  SHORT: 1,
  LONG: 2,
}

const Leverage = {
  ONE: 0,
  TWO: 1,
  THREE: 2,
  FOUR: 3,
}

const PositionStatus = {
  SAFE: 0,
  WARNING: 1,
  DANGER: 2,
}

export const usePerpetual = (
  perpetualAddress,
  account,
  library,
  tick,
  currentNetwork
) => {
  const perpetualContract = useMemo(() => {
    if (!account || !perpetualAddress || !library) {
      return
    }
    if (currentNetwork === 2) {
      return new ethers.Contract(perpetualAddress, Perpetual.abi, library)
    }
    try {
      return new ethers.Contract(
        perpetualAddress,
        Perpetual.abi,
        library.getSigner()
      )
    } catch (e) {
      return
    }
  }, [account, perpetualAddress, library])

  const [markPrice, setMarkPrice] = useState("--")
  const [indexPrice, setIndexPrice] = useState("--")
  const [totalLiquidity, setTotalLiquidity] = useState("--")
  const [liquidity, setLiquidity] = useState()

  const getMarkPrice = useCallback(async () => {
    try {
      const result = await perpetualContract.getMidPrice()
      return Number(ethers.utils.formatEther(result)).toLocaleString()
    } catch (e) {
      return "0"
    }
  }, [perpetualContract, account])

  const getTotalLiquidity = useCallback(async () => {
    try {
      const result = await perpetualContract.totalLiquidity()
      return Number(ethers.utils.formatEther(result.quote)).toLocaleString()
    } catch (e) {
      return "0"
    }
  }, [perpetualContract, account])

  const getAvailableLiquidity = useCallback(async () => {
    let availableBase = 0
    let availableQuote = 0
    let base = 0
    let quote = 0

    try {
      const result = await perpetualContract.totalLiquidity()
      availableBase = Number(ethers.utils.formatEther(result.availableBase))
      availableQuote = Number(ethers.utils.formatEther(result.availableQuote))
      base = Number(ethers.utils.formatEther(result.base))
      quote = Number(ethers.utils.formatEther(result.quote))
    } catch (e) {}

    return {
      availableBase,
      availableQuote,
      base,
      quote,
    }
  }, [perpetualContract, account])

  const getPosition = useCallback(async () => {
    const position = await perpetualContract.positions(account)

    let pnl = 0

    try {
      const pnlRaw = await perpetualContract.myPnl()
      pnl = Number(ethers.utils.formatEther(pnlRaw))
    } catch (e) {}

    return {
      locked: position.locked,
      createdDate: new Date(Number(position.entryTimestamp) * 1000),
      entryValue: Number(ethers.utils.formatEther(position.entryValue)),
      leverage: position.leverage + 1,
      leveragedAmount: Number(
        ethers.utils.formatEther(position.leveragedAmount)
      ),
      positionSize: Number(ethers.utils.formatEther(position.positionSize)),
      rawCollateral: Number(ethers.utils.formatEther(position.rawCollateral)),
      side: position.side === 2 ? "Long" : "Short",
      pnl,
    }
  }, [perpetualContract, account])

  const getBuyPrice = useCallback(
    async (amount) => {
      const result = await perpetualContract.getBuyPrice(
        ethers.utils.parseEther(`${amount}`)
      )
      return ethers.utils.formatEther(result)
    },
    [perpetualContract, account]
  )

  const getSellPrice = useCallback(
    async (amount) => {
      const result = await perpetualContract.getSellPrice(
        ethers.utils.parseEther(`${amount}`)
      )
      return ethers.utils.formatEther(result)
    },
    [perpetualContract, account]
  )

  const getIndexPrice = useCallback(async () => {
    const result = await perpetualContract.getIndexPrice()
    return ethers.utils.formatEther(result)
  }, [perpetualContract, account])

  const buy = useCallback(
    async (amount, maxColleteral, leverage) => {
      return await perpetualContract.openLongPosition(
        ethers.utils.parseEther(`${amount}`),
        ethers.utils.parseEther(`${maxColleteral}`),
        leverage
      )
    },
    [perpetualContract, account]
  )

  const sell = useCallback(
    async (amount, maxColleteral, leverage) => {
      return await perpetualContract.openShortPosition(
        ethers.utils.parseEther(`${amount}`),
        ethers.utils.parseEther(`${maxColleteral}`),
        leverage
      )
    },
    [perpetualContract, account]
  )

  const closePosition = useCallback(async () => {
    return await perpetualContract.closePosition()
  }, [perpetualContract, account])

  useEffect(() => {
    perpetualContract && getMarkPrice().then(setMarkPrice)
    perpetualContract && getIndexPrice().then(setIndexPrice)
    perpetualContract && getTotalLiquidity().then(setTotalLiquidity)
    perpetualContract && getAvailableLiquidity().then(setLiquidity)
  }, [account, perpetualContract, tick])

  return {
    perpetualAddress,
    markPrice,
    indexPrice,
    totalLiquidity,
    liquidity,
    buy,
    sell,
    getBuyPrice,
    getSellPrice,
    getPosition,
    closePosition,
  }
}
