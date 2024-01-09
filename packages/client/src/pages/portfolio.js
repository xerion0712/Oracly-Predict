import MainLayout from "@/layouts/mainLayout"
import Portfolio from "@/components/Portfolio"
import useSui from "@/hooks/useSui";

const PortfolioPage = (props) => {

    return (
        <MainLayout>
            <Portfolio
                {...props}
            />
        </MainLayout>
    )
}

export default PortfolioPage

export async function getStaticProps() {

  const { fetchSuiSystem } = useSui()

  return {
    props: {
      mainnet: await fetchSuiSystem(),
      testnet: await fetchSuiSystem("testnet")
    },
    revalidate: 600
  };
}