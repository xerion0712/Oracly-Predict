import MockToken from "@/components/MockToken"
import MainLayout from "@/layouts/mainLayout"


const Faucet = () => {

    return (
        <MainLayout>
            <div class="w-full mx-auto max-w-screen-xl p-4">
                <MockToken/>
            </div>
            
        </MainLayout>
    )
}

export default Faucet