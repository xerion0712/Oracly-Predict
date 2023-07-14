import Header from "@/components/Header"


const MainLayout = ({ children }) => {
    return (
        <main class="bg-black text-white">
            <div class="flex h-screen flex-col mx-auto"> 
                {children} 
            </div>
        </main>
    )
}

export default MainLayout