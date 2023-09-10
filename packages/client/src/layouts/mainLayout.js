import Footer from "@/components/Footer"
import Header from "@/components/Header"


const MainLayout = ({ children }) => {
    return (
        <main class="bg-slate-950 text-white">
            <div class="flex h-screen flex-col mx-auto justify-between">
                <Header />
                <div className="mb-auto">
                    {children}
                </div> 
                <Footer />
            </div>

        </main>
    )
}

export default MainLayout