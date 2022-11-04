import { ethers } from 'hardhat'

async function main() {
  // @ts-ignore
  const signer = await ethers.getSigner()
  const address = await signer.getAddress()
  console.log('signer address:', address)

  // We get the contract to deploy
  const NotesMetadataDescriptor = await ethers.getContractFactory('NotesMetadataDescriptor')
  const descriptor = await NotesMetadataDescriptor.deploy()
  await descriptor.deployed()
  console.log('NotesMetadataDescriptor deployed to:', descriptor.address)

  const Cryptonotes = await ethers.getContractFactory('Cryptonotes')

  const cryptonotes = await Cryptonotes.deploy()
  await cryptonotes.deployed()

  const tx = await cryptonotes.initialize(
    'Ethereum Commemorative Cryptonotes',
    'ETHCC',
    18,
    '0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e', // Chainlink ETH/USD price feed address Mumbai: 0x0715A7794a1dc8e42615F059dD6e406A6594651A, Goerli: 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
    descriptor.address
  )
  await tx.wait()
  console.log('Cryptonotes deployed to:', cryptonotes.address)

  // const cryptonotes = Cryptonotes.attach('0x')

  // setup a new metadta descriptor
  // const tx = await cryptonotes.setMetadataDescriptor(descriptor.address)
  // console.log('set descriptor tx hash:', tx.hash)
  // await tx.wait()

  const owner = await cryptonotes.owner()
  console.log('owner:', owner)
  const name = await cryptonotes.name()
  console.log('name:', name)
  const symbol = await cryptonotes.symbol()
  console.log('symbol:', symbol)
  // const tokenURI = await cryptonotes.tokenURI(1)
  // console.log('token URI:', tokenURI)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})

// Goerli
// Descriptor: 0x9723D5cc4098AaB073aD94935aFaFe017e739d98
// note: 0x587233290b3A8a459367cCF0ff4C5BA0E3525B11
