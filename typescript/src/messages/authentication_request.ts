import {JsonProperty, Serializable} from 'typescript-json-serializer';
import {Kind, Message} from "./message";

@Serializable()
export class AuthenticationRequest extends Message{

    public constructor(
        token: string,
        session_id: string | undefined = undefined,
    ) {
        super(Kind.AuthRequest)
        this.token = token;
        this.session_id = session_id;
    }

    @JsonProperty() token: string;
    @JsonProperty() session_id: string | undefined;
}
