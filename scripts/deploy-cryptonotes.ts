import { ethers, upgrades } from 'hardhat'

async function main() {
  // @ts-ignore
  const signer = await ethers.getSigner()
  const address = await signer.getAddress()
  console.log('signer address:', address)

  // Deploy the notes metadata descriptor contract
  const NotesMetadataDescriptor = await ethers.getContractFactory('NotesMetadataDescriptor')
  const descriptor = await NotesMetadataDescriptor.deploy()
  await descriptor.deployed()
  console.log('NotesMetadataDescriptor deployed to:', descriptor.address)

  const Cryptonotes = await ethers.getContractFactory('Cryptonotes')

  // Upgrades the Cryptonotes contract
  // const cryptonotes = await upgrades.upgradeProxy('0x', Cryptonotes)

  const cryptonotes = await upgrades.deployProxy(Cryptonotes, [
    'Community Commemorative Cryptonotes',
    'CCC',
    18,
    '0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada', // Chainlink price feed: ETH/USD - Goerli: 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e, MATIC/USD - Mumbai: 0xd0D5e3DB44DE05E9F294BB0a3bEEaF030DE24Ada, 
    descriptor.address
  ])
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
// Descriptor: 0x34145C89C1ba96C81cd14D09849c5B404bB413e6
// note: 0xA9d1E6C19e3eBc9c9c716a240C751A7c9b19C3bC

// Mumbai
// Descriptor: 0xf0Af965386A66a677dF7E463327B6A3494064924
// note: 0xf0Af965386A66a677dF7E463327B6A3494064924
