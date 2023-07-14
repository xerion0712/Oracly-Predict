import Header from "@/components/Header"


const FullLayout = ({ children }) => {
    return (
        <main class="bg-slate-950 text-white">
            <div class="flex h-screen flex-col mx-auto">
                <Header />
                {children}
            </div>
        </main>
    )
}

export default FullLayout