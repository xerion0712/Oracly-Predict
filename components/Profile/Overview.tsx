import { BadgePurple } from "../Badge";


const Overview = ({ profile }: any) => {
    return (
        <div className="bg-black/90 rounded-lg p-6">
            <h2 className="text-xl font-semibold text-white mb-4">Your Profile</h2>

            <div className="grid grid-cols-7 gap-4">
                <div className="col-span-2">
                    <p className="text-gray-300">Username</p>
                </div>
                <div className="col-span-5">
                    <span className="text-white line-clamp-1">
                        {profile && profile.username}
                    </span>
                </div>
                <div className="col-span-2">
                    <p className="text-gray-300">Role</p>
                </div>
                <div className="col-span-5">
                    <BadgePurple>
                        {profile && profile.role || "USER"}
                    </BadgePurple>
                </div>
            </div>
        </div>
    )
}

export default Overview