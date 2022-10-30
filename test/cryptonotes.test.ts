import { BigNumber, constants, utils } from 'ethers'
import { expect } from 'chai'
import { ethers } from 'hardhat'
import { Cryptonotes } from '../typechain-types'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

interface TokenData {
  id: BigNumber
  slot: BigNumber
  balance: BigNumber
  owner: string
  cryptonotes: Cryptonotes
}

const AddressZero = constants.AddressZero
const vestingType = 1
const maturity = 1
const term = 0

describe('Commemorative Cryptonotes', function () {
  const mintWithOutDeploy = async (
    cryptonotes: Cryptonotes,
    minter: SignerWithAddress,
    slot: string,
    withValue?: BigNumber,
  ): Promise<TokenData> => {
    const value = withValue || utils.parseEther('1')
    const slotDetail = {
      name: 'eth-cc',
      description: 'for testing desc',
      image: '',
      underlying: AddressZero, // zero address for ETH on Ethereum networks
      vestingType,
      maturity,
      term
    }
    const tx = await cryptonotes.connect(minter).mint(minter.address, slotDetail, value, { value })
    await tx.wait()

    let eventFilter = cryptonotes.filters['TransferValue'](0)
    let block = await ethers.provider.getBlock('latest')
    let event = await cryptonotes.queryFilter(eventFilter, block.number, 'latest')
    let args = event[0]['args']
    
    return {
      id: BigNumber.from(args[1]),
      slot: BigNumber.from(slot),
      balance: value,
      owner: minter.address,
      cryptonotes,
    }
  }

  describe('Cryptonotes', function () {
    before(async function () {
      this.slot = utils.solidityKeccak256(['address', 'uint8', 'uint32', 'uint32'], [AddressZero, vestingType, maturity, term])

      this.signers = await ethers.getSigners()
      this.deployer = this.signers[0]
      this.bob = this.signers[1]
      this.alice = this.signers[2]
      
      this.Cryptonotes = await ethers.getContractFactory('Cryptonotes', this.deployer)

      const cryptonotes: Cryptonotes = (await this.Cryptonotes.deploy()) as Cryptonotes
      this.cryptonotes = cryptonotes
      
      const PriceFeed = await ethers.getContractFactory('PriceFeed', this.deployer)
      const priceFeed = await PriceFeed.deploy()

      const NotesMetadataDescriptor = await ethers.getContractFactory('NotesMetadataDescriptor', this.deployer)
      const descriptor = await NotesMetadataDescriptor.deploy()

      const tx = await this.cryptonotes.initialize(
        'Testing Commemorative Cryptonotes',
        'TCC',
        18,
        priceFeed.address,
        descriptor.address
      )
      await tx.wait()
    })

    it('Mint a new note to Bob should be successful', async function () {
      const t = await mintWithOutDeploy(this.cryptonotes, this.bob, this.slot, utils.parseEther('0.5'))
      
      expect(await t.cryptonotes['balanceOf(address)'](this.bob.address)).to.eq(t.id)
      expect(await t.cryptonotes.ownerOf(t.id)).to.eq(this.bob.address)
      await expect(t.cryptonotes.ownerOf(5)).revertedWith('ERC3525: owner query for nonexistent token')
      expect(await t.cryptonotes['balanceOf(uint256)'](t.id)).to.eq(t.balance)
      expect(await t.cryptonotes.slotOf(t.id)).to.eq(t.slot)
      expect(await t.cryptonotes.totalSupply()).to.eq(1)
      
      // const contractURI = await t.cryptonotes.contractURI()
      // console.log('contract URI:', contractURI)

      // const slot = await t.cryptonotes.slotOf(1)
      // const slotURI = await t.cryptonotes.slotURI(slot)
      // console.log('slot URI:', slotURI)

      // const tokenURI = await t.cryptonotes.tokenURI(1)
      // console.log('token URI:', tokenURI)
    })

    it('Topup a note should be successful', async function () {
      const value = utils.parseEther('0.5')
      expect(await this.cryptonotes['balanceOf(uint256)'](1)).to.eq(value)

      const topupTx = await this.cryptonotes.connect(this.bob).topUp(this.bob.address, '1', value, { value })
      await topupTx.wait()

      expect(await this.cryptonotes['balanceOf(address)'](this.bob.address)).to.eq(1)
      expect(await this.cryptonotes['balanceOf(uint256)'](1)).to.eq(utils.parseEther('1'))
      expect(await this.cryptonotes.totalSupply()).to.eq(1)
    })

    it('Split a note to a new tokenId (same owns by Bob) should be successful', async function () {
      expect(await this.cryptonotes['balanceOf(uint256)'](1)).to.eq(utils.parseEther('1'))

      const splitTx = await this.cryptonotes.connect(this.bob)['split(uint256,uint256,uint256)']('1', '2', utils.parseEther('0.5'))
      await splitTx.wait()

      expect(await this.cryptonotes['balanceOf(address)'](this.bob.address)).to.eq(2) // after split the owner should be having 2 tokens
      expect(await this.cryptonotes.ownerOf(2)).to.eq(this.bob.address)
      await expect(this.cryptonotes.ownerOf(5)).revertedWith('ERC3525: owner query for nonexistent token')
      expect(await this.cryptonotes['balanceOf(uint256)'](1)).to.eq(await this.cryptonotes['balanceOf(uint256)'](2))
      expect(await this.cryptonotes.totalSupply()).to.eq(2) // total supply should be 2 as well
    })

    it('Split a note (from Bob to Alice) to a new address should be successful', async function () {
      const splitTx = await this.cryptonotes.connect(this.bob)['split(uint256,address,uint256)']('2', this.alice.address, utils.parseEther('0.2'))
      await splitTx.wait()
      
      expect(await this.cryptonotes['balanceOf(address)'](this.bob.address)).to.eq(2)
      expect(await this.cryptonotes['balanceOf(address)'](this.alice.address)).to.eq(1)
      expect(await this.cryptonotes.ownerOf(2)).to.eq(this.bob.address)
      expect(await this.cryptonotes.ownerOf(3)).to.eq(this.alice.address)
      await expect(this.cryptonotes.ownerOf(5)).revertedWith('ERC3525: owner query for nonexistent token')
      expect(await this.cryptonotes['balanceOf(uint256)'](2)).to.eq(utils.parseEther('0.3'))
      expect(await this.cryptonotes['balanceOf(uint256)'](3)).to.eq(utils.parseEther('0.2'))
      expect(await this.cryptonotes.totalSupply()).to.eq(3)
    })

    it('Split a note (not owned by Alice) should be failed', async function () {
      await expect(
        this.cryptonotes.connect(this.alice)['split(uint256,address,uint256)']('2', this.alice.address, utils.parseEther('0.2'))
      ).revertedWithCustomError(this.cryptonotes, 'NotAuthorised')
    })

    it('Merge a note (owns by Bob) should be successful', async function () {
      const mergeTx = await this.cryptonotes.connect(this.bob)['merge(uint256,uint256)']('1', '2')
      await mergeTx.wait()
      
      await expect(this.cryptonotes.ownerOf(1)).revertedWith('ERC3525: owner query for nonexistent token')
      expect(await this.cryptonotes['balanceOf(address)'](this.bob.address)).to.eq(1)
      expect(await this.cryptonotes['balanceOf(address)'](this.alice.address)).to.eq(1)
      expect(await this.cryptonotes.ownerOf(2)).to.eq(this.bob.address)
      expect(await this.cryptonotes.ownerOf(3)).to.eq(this.alice.address)
      expect(await this.cryptonotes['balanceOf(uint256)'](2)).to.eq(utils.parseEther('0.8'))
      expect(await this.cryptonotes.totalSupply()).to.eq(2)
    })

    it('Withdraw a note (owns by Bob) should be successful', async function () {
      const prevBalance = await ethers.provider.getBalance(this.bob.address)

      const withdrawTx = await this.cryptonotes.connect(this.bob)['withdraw(uint256)']('2')
      await withdrawTx.wait()

      const receipt = await withdrawTx.wait()
      const gasSpent = receipt.gasUsed.mul(receipt.effectiveGasPrice)
      
      expect(await this.bob.getBalance()).to.eq(prevBalance.add(utils.parseEther('0.8')).sub(gasSpent))

      await expect(this.cryptonotes.ownerOf(2)).revertedWith('ERC3525: owner query for nonexistent token')
      expect(await this.cryptonotes['balanceOf(address)'](this.bob.address)).to.eq(0)
      expect(await this.cryptonotes['balanceOf(address)'](this.alice.address)).to.eq(1)
      expect(await this.cryptonotes.ownerOf(3)).to.eq(this.alice.address)
      expect(await this.cryptonotes.totalSupply()).to.eq(1)
    })

    it('Withdraw a note (not owned by Bob) should be failed', async function () {
      await expect(
        this.cryptonotes.connect(this.bob)['withdraw(uint256)']('3')
      ).revertedWithCustomError(this.cryptonotes, 'NotAuthorised')
    })
  })

  describe('ERC721 and ERC3525 interfaces', function () {
    const deploy = async (): Promise<Cryptonotes> => {
      const Cryptonotes = await ethers.getContractFactory('Cryptonotes')
      const cryptonotes = (await Cryptonotes.deploy()) as Cryptonotes
      await cryptonotes.deployed()
      
      const tx = await cryptonotes.initialize('Test Commemorative Cryptonotes', 'TCC', 18, AddressZero, AddressZero)
      await tx.wait()
      
      return cryptonotes
    }
  
    const mint = async (slot: string = '3225'): Promise<TokenData> => {
      const cryptonotes = await deploy()
      const [minter] = await ethers.getSigners()
      return mintWithOutDeploy(cryptonotes, minter, slot)
    }
  
    const checkTransferEvent = async (cryptonotes: Cryptonotes, from: string, to: string, tokenId: BigNumber) => {
      let eventFilter = cryptonotes.filters['Transfer'](from, to)
      let block = await ethers.provider.getBlock('latest')
      let event = await cryptonotes.queryFilter(eventFilter, block.number, 'latest')
  
      let args = event[0]['args']
      expect(args[0]).to.equal(from)
      expect(args[1]).to.equal(to)
      expect(args[2]).to.equal(tokenId)
    }

    describe('ERC721 compatible interface', function () {
      it('mint should be success', async function () {
        const slot = utils.solidityKeccak256(['address', 'uint8', 'uint32', 'uint32'], [AddressZero, vestingType, maturity, term])
        const t = await mint(slot)
        
        await checkTransferEvent(t.cryptonotes, constants.AddressZero, t.owner, t.id)
  
        expect(await t.cryptonotes['balanceOf(address)'](t.owner)).to.eq(t.id)
        expect(await t.cryptonotes.ownerOf(t.id)).to.eq(t.owner)
        await expect(t.cryptonotes.ownerOf(5)).revertedWith('ERC3525: owner query for nonexistent token')
        expect(await t.cryptonotes['balanceOf(uint256)'](t.id)).to.eq(t.balance)
        expect(await t.cryptonotes.slotOf(t.id)).to.eq(t.slot)
        expect(await t.cryptonotes.totalSupply()).to.eq(1)
      })
  
      it('approve all should be success', async () => {
        const [_, approval] = await ethers.getSigners()
  
        const t = await mint()
  
        await t.cryptonotes.setApprovalForAll(approval.address, true)
        expect(await t.cryptonotes.isApprovedForAll(t.owner, approval.address)).to.eq(true)
        expect(
          await t.cryptonotes.isApprovedForAll(
            t.owner,
            '0x000000000000000000000000000000000000dEaD'
          )
        ).to.eq(false)
      })
  
      it('approve id should be success', async () => {
        const t = await mint()
  
        const [_, approval] = await ethers.getSigners()
  
        await t.cryptonotes['approve(address,uint256)'](approval.address, t.id)
        expect(await t.cryptonotes.getApproved(t.id)).to.eq(approval.address)
        await expect(
          t.cryptonotes['approve(address,uint256)'](approval.address, 5)
        ).revertedWith('ERC3525: owner query for nonexistent token')
        await expect(t.cryptonotes.getApproved(6)).revertedWith(
          'ERC3525: approved query for nonexistent token'
        )
      })
  
      it('transfer token id should be success', async () => {
        const t = await mint()
        const oldOwner = t.owner
        const [_, receiver] = await ethers.getSigners()
        
        await t.cryptonotes['transferFrom(address,address,uint256)'](
          t.owner,
          receiver.address,
          t.id
        )
  
        await checkTransferEvent(t.cryptonotes, oldOwner, receiver.address, t.id)
        const newOwner = receiver.address
        expect(await t.cryptonotes.ownerOf(t.id)).to.eq(newOwner)
        expect(await t.cryptonotes['balanceOf(address)'](newOwner)).to.eq(1)
        expect(await t.cryptonotes['balanceOf(address)'](oldOwner)).to.eq(0)
        expect(await t.cryptonotes['balanceOf(uint256)'](t.id)).to.eq(t.balance)
        expect(await t.cryptonotes.totalSupply()).to.eq(1)
      })
  
      it('allowance should be zero after transfer token id', async () => {
        const t = await mint()
        const [_, receiver, approval] = await ethers.getSigners()
        await t.cryptonotes['approve(uint256,address,uint256)'](
          t.id,
          approval.address,
          t.balance
        )
        expect(await t.cryptonotes.allowance(t.id, approval.address)).to.eq(t.balance)
        await t.cryptonotes['transferFrom(address,address,uint256)'](
          t.owner,
          receiver.address,
          t.id
        )
        expect(await t.cryptonotes.allowance(t.id, approval.address)).to.eq(0)
      })
  
      it('not owner should be rejected', async () => {
        const t = await mint()
        const [_, approval, other] = await ethers.getSigners()
        t.cryptonotes = t.cryptonotes.connect(other)
        await expect(
          t.cryptonotes['approve(uint256,address,uint256)'](
            t.id,
            approval.address,
            t.balance
          )
        ).revertedWith('ERC3525: approve caller is not owner nor approved for all')
  
        await expect(
          t.cryptonotes['transferFrom(address,address,uint256)'](
            approval.address,
            other.address,
            t.id
          )
        ).revertedWith('ERC3525: transfer caller is not owner nor approved')
      })
  
      it('transfer id should  be success after setApprovalForAll', async () => {
        const t = await mint()
        const [_, approval, receiver] = await ethers.getSigners()
        await t.cryptonotes.setApprovalForAll(approval.address, true)
        t.cryptonotes = t.cryptonotes.connect(approval)
        await t.cryptonotes['transferFrom(address,address,uint256)'](
          t.owner,
          receiver.address,
          t.id
        )
        await checkTransferEvent(t.cryptonotes, t.owner, receiver.address, t.id)
      })
  
      it('transfer should be success after approve', async () => {
        const t = await mint()
        const [_, approval, receiver] = await ethers.getSigners()
        await t.cryptonotes['approve(address,uint256)'](approval.address, t.id)
        await t.cryptonotes['transferFrom(address,address,uint256)'](
          t.owner,
          receiver.address,
          t.id
        )
        await checkTransferEvent(t.cryptonotes, t.owner, receiver.address, t.id)
      })
  
      it('balance of address should be correct after transfer id', async () => {
        const cryptonotes = await deploy()
        const [minter, receiver] = await ethers.getSigners()
  
        const tokenDatas = []
  
        for (let i = 1; i < 11; i++) {
          const tokenData = await mintWithOutDeploy(cryptonotes, minter, '3525')
          tokenDatas.push(tokenData)
        }
        expect(await cryptonotes['balanceOf(address)'](minter.address)).to.eq(10)
        for (let t of tokenDatas.slice(0, 4)) {
          await cryptonotes.withdraw(t.id)
        }
        expect(await cryptonotes['balanceOf(address)'](minter.address)).to.eq(6)
  
        for (let t of tokenDatas.slice(5, 7)) {
          await cryptonotes['transferFrom(address,address,uint256)'](
            minter.address,
            receiver.address,
            t.id
          )
        }
        expect(await cryptonotes['balanceOf(address)'](minter.address)).to.eq(4)
      })
    })
  
    describe('ERC3525 interface', function () {
      it('approve value should be success', async () => {
        const t = await mint()
  
        const [_, approval] = await ethers.getSigners()
        const approvedValue = t.balance.div(2)
  
        await t.cryptonotes['approve(uint256,address,uint256)'](
          t.id,
          approval.address,
          approvedValue
        )
        expect(await t.cryptonotes.allowance(t.id, approval.address)).to.eq(
          approvedValue
        )
        expect(
          await t.cryptonotes.allowance(
            t.id,
            '0x000000000000000000000000000000000000dEaD'
          )
        ).to.eq(0)
        expect(await t.cryptonotes.allowance(5, approval.address)).to.eq(0)
      })
  
      it('transfer value to id should be success', async () => {
        const cryptonotes = await deploy()
        const [from, to] = await ethers.getSigners()
  
        const f = await mintWithOutDeploy(cryptonotes, from, '3525')
        const t = await mintWithOutDeploy(cryptonotes, to, '3525')
        const value = f.balance.div(2)
        const expectFromValue = f.balance.sub(value)
        const expectToValue = t.balance.add(value)
  
        expect(
          await cryptonotes['transferFrom(uint256,uint256,uint256)'](
            f.id,
            t.id,
            value
          )
        )
        expect(await cryptonotes['balanceOf(uint256)'](f.id)).to.eq(expectFromValue)
        expect(await cryptonotes['balanceOf(uint256)'](t.id)).to.eq(expectToValue)
      })
  
      it('approved value should be correct after transfer value to id', async () => {
        const cryptonotes = await deploy()
        const [from, to, spender] = await ethers.getSigners()
  
        const f = await mintWithOutDeploy(cryptonotes, from, '3525')
        const t = await mintWithOutDeploy(cryptonotes, to, '3525')
        const value = f.balance.div(2)
        const expectApprovedValue = f.balance.sub(value)
  
        await cryptonotes['approve(uint256,address,uint256)'](
          f.id,
          spender.address,
          f.balance
        )
        expect(await cryptonotes.allowance(f.id, spender.address)).to.eq(f.balance)
  
        const spenderERC3525 = cryptonotes.connect(spender)
        await spenderERC3525['transferFrom(uint256,uint256,uint256)'](
          f.id,
          t.id,
          value
        )
        expect(await cryptonotes.allowance(f.id, spender.address)).to.eq(expectApprovedValue)
      })
  
      it('transfer value to id should sucess after setApprovalForAll', async () => {
        const cryptonotes = await deploy()
        const [from, to, spender] = await ethers.getSigners()
  
        const f = await mintWithOutDeploy(cryptonotes, from, '3525')
        const t = await mintWithOutDeploy(cryptonotes, to, '3525')
        const value = f.balance.div(2)
  
        await cryptonotes.setApprovalForAll(spender.address, true)
  
        const spenderERC3525 = await cryptonotes.connect(spender)
        expect(
          await spenderERC3525['transferFrom(uint256,uint256,uint256)'](
            f.id,
            t.id,
            value
          )
        )
      })
  
      it('transfer value to id should sucess after id approved', async () => {
        const cryptonotes = await deploy()
        const [from, to, spender] = await ethers.getSigners()
  
        const f = await mintWithOutDeploy(cryptonotes, from, '3525')
        const t = await mintWithOutDeploy(cryptonotes, to, '3525')
        const value = f.balance.div(2)
  
        await cryptonotes['approve(address,uint256)'](spender.address, f.id)
  
        const spenderERC3525 = await cryptonotes.connect(spender)
        expect(
          await spenderERC3525['transferFrom(uint256,uint256,uint256)'](
            f.id,
            t.id,
            value
          )
        )
      })
    })
  })

})
