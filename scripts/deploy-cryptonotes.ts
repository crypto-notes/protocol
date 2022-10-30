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

  const Cryptonotes = await ethers.getContractFactory('Cryptonotes')
  const cryptonotes = await Cryptonotes.deploy()
  await cryptonotes.deployed()

  const tx = await cryptonotes.initialize(
    'Ethereum Commemorative Cryptonotes',
    'ETHCC',
    18,
    '0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e',
    descriptor.address
  )
  await tx.wait()
  
  // const cryptonotes = Cryptonotes.attach('0x')
  
  const name = await cryptonotes.name()
  console.log('name:', name)
  const symbol = await cryptonotes.symbol()
  console.log('symbol:', symbol)

  console.log('Cryptonotes deployed to:', cryptonotes.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
