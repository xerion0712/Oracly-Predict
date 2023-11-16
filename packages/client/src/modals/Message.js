import BaseModal from "./Base"

const MessageModal = ({ visible, close, title, info }) => {
    return (
        <BaseModal
            title={title}
            visible={visible}
            close={close}
            borderColor="border-gray-700"
            maxWidth="max-w-md"
        >
            <div className="text-base h-[120px] flex flex-col justify-center items-center">
                {info}
                <button onClick={close} className="mt-4 rounded-lg  text-sm font-medium flex flex-row px-6 py-2 justify-center bg-blue-700">
                    Close
                </button>
            </div>
            
        </BaseModal>
    )
}

export default MessageModal