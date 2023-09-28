import MainLayout from "@/layouts/mainLayout"
import StakeComponent from "@/components/Stake"

const Stake = () => {
    return (
        <MainLayout>
            <div class="w-full mx-auto max-w-screen-xl p-4">
                <StakeComponent/>
            </div>
            
        </MainLayout>
    )
}

export default Stake