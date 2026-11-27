// This controller calls the original Anytype ClientCommands service. It contains
// no wallet, account, Space, object, synchronization, or editor implementation.
// Run only against the loopback RPC of the owned isolated fixture container.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/anyproto/anytype-heart/pb"
	"github.com/anyproto/anytype-heart/pb/service"
	"github.com/gogo/protobuf/types"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials/insecure"
	"google.golang.org/grpc/metadata"
)

func writePrivate(directory, name string, value []byte) error {
	file, err := os.OpenFile(filepath.Join(directory, name), os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		return err
	}
	if _, err = file.Write(value); err == nil {
		err = file.Sync()
	}
	closeErr := file.Close()
	if err != nil {
		return err
	}
	if closeErr != nil {
		return closeErr
	}
	dir, err := os.Open(directory)
	if err != nil {
		return err
	}
	defer dir.Close()
	return dir.Sync()
}

func writeJSON(directory, name string, value any) error {
	bytes, err := json.MarshalIndent(value, "", "  ")
	if err != nil {
		return err
	}
	return writePrivate(directory, name, append(bytes, '\n'))
}

func readPrivateJSON(directory, name string, value any) error {
	path := filepath.Join(directory, name)
	info, err := os.Lstat(path)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() || info.Mode().Perm()&0077 != 0 || info.Size() > 1024*1024 {
		return errors.New("require retained original private RPC response")
	}
	bytes, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	return json.Unmarshal(bytes, value)
}

func finishExistingSpace(directory string, client service.ClientCommandsClient, ctx context.Context) error {
	var session pb.RpcWalletCreateSessionResponse
	var account pb.RpcAccountCreateResponse
	var space pb.RpcWorkspaceCreateResponse
	if err := readPrivateJSON(directory, "session-response.private.json", &session); err != nil {
		return err
	}
	if err := readPrivateJSON(directory, "account-response.private.json", &account); err != nil {
		return err
	}
	if err := readPrivateJSON(directory, "space-response.private.json", &space); err != nil {
		return err
	}
	if session.GetError().GetCode() != 0 || session.Token == "" || session.AccountId == "" ||
		account.GetError().GetCode() != 0 || account.Account == nil || account.Account.Id != session.AccountId ||
		space.GetError().GetCode() != 0 || space.SpaceId == "" {
		return errors.New("only a genuine successfully created account and Space can resume")
	}
	auth := metadata.AppendToOutgoingContext(ctx, "token", session.Token)
	root := space.StartingObjectId
	if root == "" {
		// An empty native Space legitimately has no starting object. Create one
		// ordinary control page through ObjectCreate, rather than invent an ID.
		marker, response := "control-object-may-have-dispatched.json", "control-object-response.private.json"
		if _, err := os.Lstat(filepath.Join(directory, marker)); err == nil {
			// The exact v0.51.9 native source returns this type-parse error
			// before CreateObject. Admit only this known pre-write rejection,
			// retain its response, and fence the corrected request separately.
			var prior pb.RpcObjectCreateResponse
			if err := readPrivateJSON(directory, response, &prior); err != nil {
				return err
			}
			if prior.GetError().GetCode() != 1 || prior.ObjectId != "" || prior.GetError().GetDescription() != "get type key from raw unique key: invalid key format: empty key" {
				return errors.New("preserve possible prior object creation; reconciliation required")
			}
			marker, response = "control-object-type-corrected-may-have-dispatched.json", "control-object-type-corrected-response.private.json"
		}
		if err := writeJSON(directory, marker, map[string]string{"space_id": space.SpaceId, "object_type_unique_key": "ot-page"}); err != nil {
			return err
		}
		object, err := client.ObjectCreate(auth, &pb.RpcObjectCreateRequest{
			SpaceId: space.SpaceId, ObjectTypeUniqueKey: "ot-page", Details: &types.Struct{
				Fields: map[string]*types.Value{"name": {Kind: &types.Value_StringValue{StringValue: "Original network fixture control"}}},
			},
		})
		if err != nil {
			return fmt.Errorf("original ObjectCreate transport; preserve outcome: %w", err)
		}
		if err := writeJSON(directory, response, object); err != nil {
			return err
		}
		if object.GetError().GetCode() != 0 || object.ObjectId == "" {
			return fmt.Errorf("original ObjectCreate code %d", object.GetError().GetCode())
		}
		root = object.ObjectId
	}
	result := map[string]any{
		"schema":     "otzaria.original.native.account-fixture.v1",
		"status":     "ACTUAL_ORIGINAL_NATIVE_ACCOUNT_AND_SPACE_CREATED",
		"account_id": session.AccountId, "space_id": space.SpaceId,
		"space_title": "Otzaria original network acceptance", "object_id": root,
		"created_utc":      time.Now().UTC().Format(time.RFC3339),
		"account_creation": "original WalletCreate/WalletCreateSession/AccountCreate/AccountSelect",
		"space_creation":   "original WorkspaceCreate", "control_object_creation": "original ObjectCreate or native starting object",
		"peer_sync_proven": false, "product_acceptance_credit": false,
	}
	if err := writeJSON(directory, "source-pointer.json", result); err != nil {
		return err
	}
	bytes, err := json.Marshal(result)
	if err != nil {
		return err
	}
	fmt.Println(string(bytes))
	return nil
}

func run() error {
	directory := flag.String("evidence", "", "New private evidence directory inside the owned container")
	network := flag.String("network", "/worker/network.yml", "Original pinned client YAML")
	finish := flag.Bool("finish-existing-space", false, "Complete only a retained actual successful Space creation")
	stop := flag.Bool("stop-existing-account", false, "Stop only the actual created account, retaining all native data")
	flag.Parse()
	if !strings.HasPrefix(*directory, "/root/.anytype/") || filepath.Clean(*directory) != *directory {
		return errors.New("require a new owned private fixture directory")
	}
	if *finish || *stop {
		ctx, cancel := context.WithTimeout(context.Background(), time.Minute)
		defer cancel()
		conn, err := grpc.NewClient("127.0.0.1:31010", grpc.WithTransportCredentials(insecure.NewCredentials()))
		if err != nil {
			return err
		}
		defer conn.Close()
		client := service.NewClientCommandsClient(conn)
		if *stop {
			var session pb.RpcWalletCreateSessionResponse
			if err := readPrivateJSON(*directory, "session-response.private.json", &session); err != nil {
				return err
			}
			if session.GetError().GetCode() != 0 || session.Token == "" || session.AccountId == "" {
				return errors.New("require actual authenticated fixture account")
			}
			if err := writeJSON(*directory, "account-stop-may-have-dispatched.json", map[string]string{"account_id": session.AccountId}); err != nil {
				return err
			}
			actual, err := client.AccountStop(metadata.AppendToOutgoingContext(ctx, "token", session.Token), &pb.RpcAccountStopRequest{RemoveData: false})
			if err != nil {
				return fmt.Errorf("original AccountStop transport; retain state: %w", err)
			}
			if err := writeJSON(*directory, "account-stop-response.private.json", actual); err != nil {
				return err
			}
			if actual.GetError().GetCode() != 0 {
				return fmt.Errorf("original AccountStop code %d", actual.GetError().GetCode())
			}
			return writeJSON(*directory, "account-stop.json", map[string]any{"schema": "otzaria.original.native.account-stop.v1", "account_id": session.AccountId, "native_response_code": 0, "remove_data": false, "remote_device_acknowledgement": false})
		}
		return finishExistingSpace(*directory, client, ctx)
	}
	if _, err := os.Lstat(*directory); !errors.Is(err, os.ErrNotExist) {
		return errors.New("retain the previous wallet/possible-dispatch outcome; never create another on retry")
	}
	if err := os.Mkdir(*directory, 0700); err != nil {
		return err
	}
	if err := writeJSON(*directory, "intent.json", map[string]any{
		"schema":      "otzaria.original.native.account-fixture-intent.v1",
		"created_utc": time.Now().UTC().Format(time.RFC3339),
		"endpoint":    "127.0.0.1:31010", "network_path": *network,
		"runtime": "original anytype-cli native ClientCommands service",
	}); err != nil {
		return err
	}
	ctx, cancel := context.WithTimeout(context.Background(), 4*time.Minute)
	defer cancel()
	conn, err := grpc.NewClient("127.0.0.1:31010", grpc.WithTransportCredentials(insecure.NewCredentials()))
	if err != nil {
		return err
	}
	defer conn.Close()
	client := service.NewClientCommandsClient(conn)
	initial, err := client.InitialSetParameters(ctx, &pb.RpcInitialSetParametersRequest{
		Platform: "linux", Version: "v0.5.4", Workdir: "/root/.config/anytype",
	})
	if err != nil {
		return fmt.Errorf("original InitialSetParameters transport: %w", err)
	}
	if initial.GetError().GetCode() != 0 {
		return fmt.Errorf("original InitialSetParameters code %d", initial.GetError().GetCode())
	}
	if err := writeJSON(*directory, "wallet-may-have-dispatched.json", map[string]bool{"dispatched": true}); err != nil {
		return err
	}
	wallet, err := client.WalletCreate(ctx, &pb.RpcWalletCreateRequest{RootPath: "/root/.config/anytype/data"})
	if err != nil {
		return fmt.Errorf("original WalletCreate transport; preserve outcome: %w", err)
	}
	// Preserve the original response, including BOTH original credential forms,
	// before any native account mutation. The CLI's JSON projection keeps only
	// accountKey, whereas the unmodified original iOS login uses mnemonic.
	if err := writeJSON(*directory, "wallet-response.private.json", wallet); err != nil {
		return err
	}
	if wallet.GetError().GetCode() != 0 {
		return fmt.Errorf("original WalletCreate code %d", wallet.GetError().GetCode())
	}
	if len(strings.Fields(wallet.Mnemonic)) != 12 || wallet.AccountKey == "" {
		return errors.New("original wallet did not return both required original credential forms")
	}
	if err := writePrivate(*directory, "development-mnemonic.private", []byte(wallet.Mnemonic+"\n")); err != nil {
		return err
	}
	session, err := client.WalletCreateSession(ctx, &pb.RpcWalletCreateSessionRequest{
		Auth: &pb.RpcWalletCreateSessionRequestAuthOfAccountKey{AccountKey: wallet.AccountKey},
	})
	if err != nil {
		return fmt.Errorf("original WalletCreateSession transport: %w", err)
	}
	if err := writeJSON(*directory, "session-response.private.json", session); err != nil {
		return err
	}
	if session.GetError().GetCode() != 0 || session.AccountId == "" || session.Token == "" {
		return errors.New("original session did not authenticate the generated wallet")
	}
	auth := metadata.AppendToOutgoingContext(ctx, "token", session.Token)
	if err := writeJSON(*directory, "account-may-have-dispatched.json", map[string]string{"account_id": session.AccountId}); err != nil {
		return err
	}
	account, err := client.AccountCreate(auth, &pb.RpcAccountCreateRequest{
		Name: "Otzaria original UI pair 20261127", StorePath: "/root/.config/anytype/data",
		JsonApiListenAddr: "127.0.0.1:31012", NetworkMode: pb.RpcAccount_CustomConfig,
		NetworkCustomConfigFilePath: *network, PreferYamuxTransport: true,
	})
	if err != nil {
		return fmt.Errorf("original AccountCreate transport; preserve outcome: %w", err)
	}
	if err := writeJSON(*directory, "account-response.private.json", account); err != nil {
		return err
	}
	if account.GetError().GetCode() != 0 || account.Account == nil || account.Account.Id != session.AccountId {
		return fmt.Errorf("original AccountCreate did not confirm expected identity (code %d)", account.GetError().GetCode())
	}
	selectResult, err := client.AccountSelect(auth, &pb.RpcAccountSelectRequest{
		Id: session.AccountId, RootPath: "/root/.config/anytype/data", JsonApiListenAddr: "127.0.0.1:31012",
		NetworkMode: pb.RpcAccount_CustomConfig, NetworkCustomConfigFilePath: *network, PreferYamuxTransport: true,
	})
	if err != nil {
		return fmt.Errorf("original AccountSelect transport: %w", err)
	}
	if err := writeJSON(*directory, "selected-account-response.private.json", selectResult); err != nil {
		return err
	}
	if selectResult.GetError().GetCode() != 0 || selectResult.Account == nil || selectResult.Account.Id != session.AccountId {
		return errors.New("original AccountSelect did not preserve the generated account")
	}
	const title = "Otzaria original network acceptance"
	if err := writeJSON(*directory, "space-may-have-dispatched.json", map[string]string{"title": title}); err != nil {
		return err
	}
	space, err := client.WorkspaceCreate(auth, &pb.RpcWorkspaceCreateRequest{Details: &types.Struct{
		Fields: map[string]*types.Value{"name": {Kind: &types.Value_StringValue{StringValue: title}}},
	}})
	if err != nil {
		return fmt.Errorf("original WorkspaceCreate transport; preserve outcome: %w", err)
	}
	if err := writeJSON(*directory, "space-response.private.json", space); err != nil {
		return err
	}
	if space.GetError().GetCode() != 0 || space.SpaceId == "" {
		return fmt.Errorf("original WorkspaceCreate did not return actual Space/root (code %d)", space.GetError().GetCode())
	}
	return finishExistingSpace(*directory, client, ctx)
}

func main() {
	if err := run(); err != nil {
		// Recovery material is never formatted by this controller. RPC errors and
		// native integer status codes may be retained in the private driver log.
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
