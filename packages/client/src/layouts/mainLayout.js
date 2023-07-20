import Footer from "@/components/Footer"
import Header from "@/components/Header"

const MainLayout = ({ children }) => {
    return (
        <main class="bg-slate-950 text-white">
            <div class="flex h-screen flex-col mx-auto">
                <Header />
                {children}
            </div>
             <Footer/>
        </main>
    )
}

export default MainLayout