import BaseModal from "./Base"



const DisclaimerModal = ({ visible, close }) => {

    return (
        <BaseModal
            title="Under Development"
            visible={visible}
            close={close}
        >
            The project is currently in development and we anticipate the Mainnet version will be ready by the end of 2023.
            <div class="flex">
                <button onClick={close} className="mt-4 ml-auto py-2 rounded-lg pl-10 pr-10 text-sm font-medium flex flex-row  justify-center bg-blue-700">
                    Close
                </button>
            </div>
        </BaseModal>
    )
}

export default DisclaimerModal