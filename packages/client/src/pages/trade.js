import MainLayout from "@/layouts/mainLayout"
import Trade from "@/components/Trade"

const TradePage = () => {
    return (
        <MainLayout
            bodyClassname="my-auto"
        >
            <Trade/> 
        </MainLayout>
    )
}

export default TradePage