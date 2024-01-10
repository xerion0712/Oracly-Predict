
import useSui from "@/hooks/useSui";
import Stake from "../components/Stake"

import MainLayout from '@/layouts/mainLayout';

export default function Home(props) {

  return (
    <MainLayout>
      <Stake
        {...props}
      /> 
    </MainLayout>
  )
}

export async function getStaticProps() {

  const { fetchSuiSystem, getSuiPrice, fetchAllVault } = useSui()

  const suiPrice = await getSuiPrice()

  const { summary, avgApy, validators } = await fetchSuiSystem()

  const vaults = await fetchAllVault("mainnet", summary, suiPrice)

  return {
    props: {
      summary,
      validators,
      avgApy,
      suiPrice,
      vaults
    },
    revalidate: 600
  };
}