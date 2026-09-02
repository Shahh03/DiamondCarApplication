import {
  ArrowBackRounded,
  CheckCircleOutlineRounded,
  CloudUploadOutlined,
  CloseRounded,
  DirectionsCarOutlined,
} from '@mui/icons-material';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useEffect, useMemo, useState, type FormEvent } from 'react';
import { Link, useNavigate } from 'react-router-dom';

import {
  createProviderFleetVehicle,
  getCarCatalog,
  uploadProviderFleetVehicleImages,
} from '../../../../api/provider/providerFleetApi';
import { readSession } from '../../../../core/session';

import './ProviderFleetAddPage.css';

interface AddVehicleForm {
  carId: string;
  color: string;
  registrationNumber: string;
  rentalPricePerDay: string;
  depositAmount: string;
  insuranceCompany: string;
  policyNumber: string;
  expiryDate: string;
}

const EMPTY_FORM: AddVehicleForm = {
  carId: '',
  color: '',
  registrationNumber: '',
  rentalPricePerDay: '',
  depositAmount: '',
  insuranceCompany: '',
  policyNumber: '',
  expiryDate: '',
};

export default function ProviderFleetAddPage() {
  const providerId = readSession()?.user._id ?? '';
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [form, setForm] = useState(EMPTY_FORM);
  const [files, setFiles] = useState<File[]>([]);
  const [createdVehicleId, setCreatedVehicleId] = useState('');
  const [error, setError] = useState('');

  const carQuery = useQuery({
    queryKey: ['car-catalogue'],
    queryFn: getCarCatalog,
  });

  const previews = useMemo(
    () => files.map((file) => ({ file, url: URL.createObjectURL(file) })),
    [files],
  );

  useEffect(
    () => () => previews.forEach((preview) => URL.revokeObjectURL(preview.url)),
    [previews],
  );

  const selectedCar = carQuery.data?.find((car) => car._id === form.carId);

  const submitMutation = useMutation({
    mutationFn: async () => {
      let vehicleId = createdVehicleId;
      if (!vehicleId) {
        const vehicle = await createProviderFleetVehicle({
          provider: providerId,
          car: form.carId,
          color: form.color.trim(),
          registrationNumber: form.registrationNumber.trim().toUpperCase(),
          rentalPricePerDay: Number(form.rentalPricePerDay),
          depositAmount: Number(form.depositAmount),
          insuranceDetails: {
            insuranceCompany: form.insuranceCompany.trim(),
            policyNumber: form.policyNumber.trim(),
            expiryDate: form.expiryDate,
          },
        });
        vehicleId = vehicle._id;
        setCreatedVehicleId(vehicleId);
      }

      await uploadProviderFleetVehicleImages(vehicleId, files);
      return vehicleId;
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ['provider', providerId] });
      navigate('/provider/fleet?submitted=1', { replace: true });
    },
    onError: (mutationError: Error) => setError(mutationError.message),
  });

  function setField<K extends keyof AddVehicleForm>(
    field: K,
    value: AddVehicleForm[K],
  ) {
    setForm((current) => ({ ...current, [field]: value }));
    setError('');
  }

  function addFiles(selected: FileList | null) {
    if (!selected) return;
    const images = Array.from(selected).filter((file) =>
      file.type.startsWith('image/'),
    );
    setFiles((current) => [...current, ...images].slice(0, 10));
    setError('');
  }

  function validate(): string | null {
    if (!providerId) return 'Your provider session is missing. Sign in again.';
    if (!form.carId) return 'Select a car model.';
    if (!form.color.trim()) return 'Enter the vehicle color.';
    if (!form.registrationNumber.trim()) return 'Enter the registration number.';
    if (Number(form.rentalPricePerDay) < 0 || !form.rentalPricePerDay) {
      return 'Enter a valid daily rental price.';
    }
    if (Number(form.depositAmount) < 0 || !form.depositAmount) {
      return 'Enter a valid deposit amount.';
    }
    if (!form.insuranceCompany.trim() || !form.policyNumber.trim() || !form.expiryDate) {
      return 'Complete all insurance information.';
    }
    if (new Date(form.expiryDate).getTime() <= Date.now()) {
      return 'The insurance policy must expire in the future.';
    }
    if (!files.length) return 'Upload at least one clear vehicle photo.';
    return null;
  }

  function submit(event: FormEvent) {
    event.preventDefault();
    const validationError = validate();
    if (validationError) {
      setError(validationError);
      return;
    }
    setError('');
    submitMutation.mutate();
  }

  if (carQuery.isPending) {
    return <main className="provider-fleet-add-state">Loading car catalogue…</main>;
  }

  if (carQuery.isError) {
    return (
      <main className="provider-fleet-add-state">
        <DirectionsCarOutlined />
        <h1>Car catalogue unavailable</h1>
        <p>{carQuery.error.message}</p>
        <button type="button" onClick={() => void carQuery.refetch()}>Try again</button>
      </main>
    );
  }

  return (
    <main className="provider-fleet-add-page">
      <header className="provider-fleet-add-heading">
        <div>
          <Link to="/provider/fleet"><ArrowBackRounded />Back to fleet</Link>
          <h1>Add a vehicle</h1>
          <p>Submit vehicle and insurance details for admin approval.</p>
        </div>
        <span><CheckCircleOutlineRounded />Admin review required</span>
      </header>

      <form onSubmit={submit}>
        {createdVehicleId && (
          <div className="provider-fleet-add-partial">
            The vehicle details were saved. Retry to finish uploading its photos.
          </div>
        )}
        {error && <div className="provider-fleet-add-error" role="alert">{error}</div>}

        <section className="provider-fleet-add-card">
          <header><span>1</span><div><h2>Vehicle model</h2><p>Select the shared make and model.</p></div></header>
          <label className="provider-fleet-add-field wide">
            <span>Car model *</span>
            <select
              value={form.carId}
              disabled={Boolean(createdVehicleId)}
              onChange={(event) => setField('carId', event.target.value)}
            >
              <option value="">Select a model</option>
              {(carQuery.data ?? []).map((car) => (
                <option key={car._id} value={car._id}>
                  {car.brand} {car.model} · {car.year} · {car.category}
                </option>
              ))}
            </select>
          </label>
          {selectedCar && (
            <div className="provider-fleet-add-model-summary">
              <DirectionsCarOutlined />
              <div><strong>{selectedCar.brand} {selectedCar.model}</strong><small>{selectedCar.year} · {selectedCar.category} · {selectedCar.transmission} · {selectedCar.fuelType} · {selectedCar.seats} seats</small></div>
            </div>
          )}
        </section>

        <section className="provider-fleet-add-card">
          <header><span>2</span><div><h2>Vehicle and pricing</h2><p>Enter details unique to this vehicle.</p></div></header>
          <div className="provider-fleet-add-grid">
            <TextField label="Color *" value={form.color} disabled={Boolean(createdVehicleId)} onChange={(value) => setField('color', value)} />
            <TextField label="Registration number *" value={form.registrationNumber} disabled={Boolean(createdVehicleId)} onChange={(value) => setField('registrationNumber', value)} />
            <TextField label="Daily price (AED) *" type="number" min="0" value={form.rentalPricePerDay} disabled={Boolean(createdVehicleId)} onChange={(value) => setField('rentalPricePerDay', value)} />
            <TextField label="Deposit (AED) *" type="number" min="0" value={form.depositAmount} disabled={Boolean(createdVehicleId)} onChange={(value) => setField('depositAmount', value)} />
          </div>
        </section>

        <section className="provider-fleet-add-card">
          <header><span>3</span><div><h2>Insurance</h2><p>Admin will verify the active insurance policy.</p></div></header>
          <div className="provider-fleet-add-grid">
            <TextField label="Insurance company *" value={form.insuranceCompany} disabled={Boolean(createdVehicleId)} onChange={(value) => setField('insuranceCompany', value)} />
            <TextField label="Policy number *" value={form.policyNumber} disabled={Boolean(createdVehicleId)} onChange={(value) => setField('policyNumber', value)} />
            <TextField label="Expiry date *" type="date" value={form.expiryDate} disabled={Boolean(createdVehicleId)} onChange={(value) => setField('expiryDate', value)} />
          </div>
        </section>

        <section className="provider-fleet-add-card">
          <header><span>4</span><div><h2>Vehicle photos</h2><p>Upload 1–10 clear exterior and interior photos.</p></div></header>
          <label className="provider-fleet-add-upload">
            <CloudUploadOutlined />
            <strong>Choose vehicle photos</strong>
            <small>JPG, PNG, HEIC or WEBP · maximum 10 files</small>
            <input type="file" accept="image/*" multiple onChange={(event) => addFiles(event.target.files)} />
          </label>
          {previews.length > 0 && (
            <div className="provider-fleet-add-previews">
              {previews.map(({ file, url }, index) => (
                <figure key={`${file.name}-${file.lastModified}-${index}`}>
                  <img src={url} alt="Vehicle preview" />
                  {index === 0 && <b>Cover</b>}
                  <button type="button" aria-label="Remove photo" onClick={() => setFiles((current) => current.filter((_, fileIndex) => fileIndex !== index))}><CloseRounded /></button>
                </figure>
              ))}
            </div>
          )}
        </section>

        <footer className="provider-fleet-add-actions">
          <Link to="/provider/fleet">Cancel</Link>
          <button type="submit" disabled={submitMutation.isPending}>
            {submitMutation.isPending
              ? 'Submitting…'
              : createdVehicleId
                ? 'Retry photo upload'
                : 'Submit for review'}
          </button>
        </footer>
      </form>
    </main>
  );
}

function TextField({
  label,
  value,
  onChange,
  disabled,
  type = 'text',
  min,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  disabled: boolean;
  type?: string;
  min?: string;
}) {
  return (
    <label className="provider-fleet-add-field">
      <span>{label}</span>
      <input type={type} min={min} value={value} disabled={disabled} onChange={(event) => onChange(event.target.value)} />
    </label>
  );
}
